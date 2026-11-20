<#
.SYNOPSIS
  Verificações estáticas do NEXO DUAL GPU LAB (sem GPU, sem rede, sem alterar arquivos).

.DESCRIPTION
  Roda em Windows PowerShell 5.1 e em PowerShell 7 (Windows/Linux). Não compila,
  não executa benchmarks e não toca em hardware. Passar aqui NÃO valida
  comportamento Multi-GPU real.

  Checagens:
    1. VERSION em SemVer e coerente com CHANGELOG.md.
    2. CSVs históricos: cabeçalho esperado, contagens, aquecimentos, PASS/FAIL.
    3. summary-statistics.csv e transfer-summary-statistics.csv recalculados.
    4. Links relativos em Markdown apontam para arquivos rastreados.
    5. Padrões de credenciais em arquivos rastreados.
    6. Caminhos absolutos fora da lista de exceções conhecidas (aviso).
    7. Sintaxe de todos os .ps1 rastreados (parser do PowerShell).
    8. git fsck (quando git estiver disponível).

  Código de saída: 0 = PASS, 1 = FAIL.
#>
[CmdletBinding()]
param([switch]$SkipGit)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$script:pass = 0; $script:fail = 0; $script:warn = 0
function Ok($m)   { $script:pass++; Write-Host "PASS  $m" }
function Bad($m)  { $script:fail++; Write-Host "FAIL  $m" -ForegroundColor Red }
function Warn($m) { $script:warn++; Write-Host "WARN  $m" -ForegroundColor Yellow }
function Check($cond, $m) { if ($cond) { Ok $m } else { Bad $m } }

Push-Location $repo
try {
  $tracked = @(git ls-files 2>$null)
  if (-not $tracked.Count) { $tracked = @(Get-ChildItem -Recurse -File | ForEach-Object { $_.FullName.Substring($repo.Length + 1) -replace '\\', '/' }) }

  # 1. SemVer
  $ver = (Get-Content -LiteralPath 'VERSION' -Raw).Trim([char]0xFEFF, ' ', "`r", "`n")
  Check ($ver -match '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?$') "VERSION '$ver' é SemVer"
  Check ((Get-Content -LiteralPath 'CHANGELOG.md' -Raw) -match [regex]::Escape("[$ver]")) "CHANGELOG.md tem a seção [$ver]"

  # 2. CSVs históricos
  function Csv($p) { Import-Csv -LiteralPath $p }
  $b = @(Csv 'benchmarks/phase3/benchmark.csv')
  $t = @(Csv 'benchmarks/phase3/transfer-benchmark.csv')
  $p2 = @(Csv 'benchmarks/phase2/benchmark.csv')
  Check ($p2.Count -eq 6 -and @($p2 | Where-Object validation -ne 'PASS').Count -eq 0) 'Fase 2: 6 registros, todos PASS'
  Check ($b.Count -eq 1200) "Fase 3 compute: 1200 linhas (achou $($b.Count))"
  Check (@($b | Where-Object warmup -eq '1').Count -eq 240) 'Fase 3 compute: 240 aquecimentos'
  Check (@($b | Where-Object warmup -eq '0').Count -eq 960) 'Fase 3 compute: 960 medições'
  Check (@($b | Where-Object validation -ne 'PASS').Count -eq 0) 'Fase 3 compute: nenhuma linha FAIL'
  Check ($t.Count -eq 500 -and @($t | Where-Object warmup -eq '0').Count -eq 400) 'Fase 3 transferência: 500 linhas, 400 medições'
  Check (@($t | Where-Object validation -ne 'PASS').Count -eq 0) 'Fase 3 transferência: nenhuma linha FAIL'
  $groups = $b | Where-Object warmup -eq '0' | Group-Object elements, mode, gpu970_share_percent
  Check (@($groups).Count -eq 48 -and @($groups | Where-Object Count -ne 20).Count -eq 0) 'Fase 3 compute: 48 grupos x 20 medições'

  # 3. Estatísticas recalculadas
  $inv = [Globalization.CultureInfo]::InvariantCulture
  function Stats([double[]]$v) {
    $s = $v | Sort-Object; $n = $s.Count; $m = ($s | Measure-Object -Average).Average
    $med = if ($n % 2) { $s[[int][math]::Floor($n / 2)] } else { ($s[$n / 2 - 1] + $s[$n / 2]) / 2 }
    $ss = 0.0; foreach ($x in $s) { $ss += ($x - $m) * ($x - $m) }
    @($m, $med, [math]::Sqrt($ss / ($n - 1)), $s[[math]::Ceiling(0.95 * $n) - 1])
  }
  function Same($a, $c) { for ($i = 0; $i -lt 4; $i++) { if ([math]::Abs($a[$i] - $c[$i]) -gt 0.00051) { return $false } }; $true }
  $bad = 0
  foreach ($s in (Csv 'benchmarks/phase3/summary-statistics.csv')) {
    $v = [double[]]@($b | Where-Object { $_.warmup -eq '0' -and $_.elements -eq $s.Elements -and $_.mode -eq $s.Mode -and $_.gpu970_share_percent -eq $s.GPU970SharePercent } | ForEach-Object { [double]::Parse($_.total_ms, $inv) })
    $pub = @($s.TotalMeanMs, $s.TotalMedianMs, $s.TotalStdDevMs, $s.TotalP95Ms) | ForEach-Object { [double]::Parse($_, $inv) }
    if (-not (Same (Stats $v) $pub)) { $bad++ }
  }
  Check ($bad -eq 0) "summary-statistics.csv confere com os dados brutos ($bad divergências)"
  $bad = 0
  foreach ($s in (Csv 'benchmarks/phase3/transfer-summary-statistics.csv')) {
    $v = [double[]]@($t | Where-Object { $_.warmup -eq '0' -and $_.elements -eq $s.Elements -and $_.gpu970_share_percent -eq $s.GPU970SharePercent } | ForEach-Object { [double]::Parse($_.transfer_ms, $inv) })
    $pub = @($s.TransferMeanMs, $s.TransferMedianMs, $s.TransferStdDevMs, $s.TransferP95Ms) | ForEach-Object { [double]::Parse($_, $inv) }
    if (-not (Same (Stats $v) $pub)) { $bad++ }
  }
  Check ($bad -eq 0) "transfer-summary-statistics.csv confere com os dados brutos ($bad divergências)"

  # 4. Links Markdown (somente relativos; ignora http, mailto e âncoras puras)
  $trackedSet = @{}; foreach ($f in $tracked) { $trackedSet[$f.ToLowerInvariant()] = $true }
  $legacy = @('docs/phase2-report.md', 'docs/phase3-report.md', 'docs/phase1-hardware-report.md', 'phases/phase1-diagnostic/evidence/relatorio-hardware.md')
  $broken = @(); $legacyBroken = 0
  foreach ($md in ($tracked | Where-Object { $_ -like '*.md' })) {
    $text = Get-Content -LiteralPath $md -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($text, '\]\(([^)\s]+)\)')) {
      $target = $m.Groups[1].Value
      if ($target -match '^(https?:|mailto:|#)') { continue }
      $target = ($target -split '#')[0]
      if (-not $target) { continue }
      $dir = Split-Path -Parent $md
      $joined = if ($dir) { Join-Path $dir $target } else { $target }
      $full = [IO.Path]::GetFullPath((Join-Path $repo $joined))
      $rel = $full.Substring($repo.Length).TrimStart('\', '/') -replace '\\', '/'
      $isDir = @($tracked | Where-Object { $_.StartsWith($rel.TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
      if (-not $trackedSet.ContainsKey($rel.ToLowerInvariant()) -and -not $isDir) {
        if ($legacy -contains $md) { $legacyBroken++ } else { $broken += "$md -> $target" }
      }
    }
  }
  Check ($broken.Count -eq 0) "links Markdown relativos válidos fora dos relatórios históricos ($($broken.Count) quebrados)"
  foreach ($x in $broken) { Write-Host "      $x" }
  if ($legacyBroken) { Warn "$legacyBroken links quebrados em relatórios históricos preservados byte a byte (ver docs/audit)" }

  # 5. Credenciais
  $secretRx = 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{32,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}'
  $hits = @()
  foreach ($f in $tracked) {
    if ($f -match '\.(ico|png|jpg|exe|dll|cso)$') { continue }
    $raw = [IO.File]::ReadAllText((Join-Path $repo $f))
    if ($raw -match $secretRx) { $hits += $f }
  }
  Check ($hits.Count -eq 0) "nenhum padrão de credencial em arquivos rastreados ($($hits -join ', '))"
  Check (-not ($tracked | Where-Object { $_ -match '(^|/)\.env($|\.)' -and $_ -notmatch '\.env\.example$' })) 'nenhum .env rastreado'

  # 6. Caminhos absolutos (aviso; exceções conhecidas documentadas em docs/privacy-review.md)
  $known = @('copy-manifest.csv', 'docs/privacy-review.md', 'phases/phase1-diagnostic/evidence/diagnostico-completo.txt', 'phases/phase1-diagnostic/evidence/nvidia-e-cuda.txt',
             'phases/phase2-prototype/source/build.ps1', 'phases/phase3-optimization/source/build.ps1', 'phases/phase3-optimization/source/run-suite.ps1',
             'phases/phase4-monitoring/ACTIVE-LOGS.md', 'phases/phase4-monitoring/source/stop-monitor.ps1', 'phases/phase4-monitoring/source/monitor.ps1', 'scripts/validate-version.ps1')
  $pathHits = @()
  foreach ($f in ($tracked | Where-Object { $_ -match '\.(md|txt|ps1|csv|cpp|hlsl|json|yml)$' })) {
    if ($known -contains $f -or $f -like 'docs/audit/*' -or $f -eq 'scripts/static-checks.ps1') { continue }
    $raw = [IO.File]::ReadAllText((Join-Path $repo $f))
    if ($raw -match '(?<![A-Za-z])[C-Z]:\\[A-Za-z]') { $pathHits += $f }
  }
  if ($pathHits.Count) { Warn "caminhos absolutos fora da lista conhecida: $($pathHits -join ', ')" } else { Ok 'nenhum caminho absoluto novo fora da lista conhecida' }
  if (@($tracked | Where-Object { $_ -match '(?i)users[\\/]' }).Count) { Bad 'arquivo rastreado sob pasta de usuário' }

  # 7. Sintaxe PowerShell
  $psBad = @()
  foreach ($f in ($tracked | Where-Object { $_ -like '*.ps1' })) {
    $tok = $null; $err = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $f), [ref]$tok, [ref]$err)
    if ($err.Count) { $psBad += "$f ($($err[0].Message))" }
  }
  Check ($psBad.Count -eq 0) "sintaxe PowerShell de todos os .ps1 ($($psBad -join '; '))"

  # 8. Integridade Git
  if (-not $SkipGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
    git fsck --no-progress --no-dangling 2>&1 | Out-Null
    Check ($LASTEXITCODE -eq 0) 'git fsck sem erros'
  }
}
finally { Pop-Location }

Write-Host ''
Write-Host "Resumo: PASS=$script:pass FAIL=$script:fail WARN=$script:warn"
Write-Host 'Aviso: verificações estáticas. Nenhuma GPU foi usada; isto não é teste Multi-GPU.'
if ($script:fail) { Write-Host 'RESULT=FAIL'; exit 1 } else { Write-Host 'RESULT=PASS'; exit 0 }
