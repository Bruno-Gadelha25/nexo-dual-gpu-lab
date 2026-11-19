[CmdletBinding()]
param([switch]$SelfTest, [string]$PolicyPath)
# NEXO GPU CONTROL v2.0 (2026-11-19)
#  - Painel de dois canais: GTX 970 (âmbar) e GTX 750 Ti (ciano), todas as métricas que o nvidia-smi expõe.
#  - Faixa de histórico com as duas curvas de uso sobrepostas (60 s).
#  - Botão que executa o NEXO GPU ENGINE (job do NEXO dividido entre as placas) e mostra o resultado.
#  - Telemetria em runspace de fundo (a janela não trava). PnP a cada 30 s. Placas por DeviceId.
#  - Contrato da política (schemaVersion 1) inalterado. Somente leitura de hardware.
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Inicie com powershell.exe -STA -NoProfile -File NexoGpuControl.ps1' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$script:AppRoot = $PSScriptRoot
if (!$PolicyPath) { $PolicyPath = Join-Path $PSScriptRoot 'scheduler-policy.json' }
$script:PolicyPath = [IO.Path]::GetFullPath($PolicyPath)
$script:EngineExe = Join-Path $script:AppRoot 'NexoGpuEngine.exe'
$script:EngineStatus = Join-Path $script:AppRoot 'engine-status.json'
$script:MaxBackups = 10
$script:HistoryLen = 60

# ---------- paleta e tipografia ----------
$C = @{
    Bg      = [Drawing.Color]::FromArgb(36, 42, 50)     # ardósia
    Panel   = [Drawing.Color]::FromArgb(28, 33, 40)     # painel de leitura
    Grid    = [Drawing.Color]::FromArgb(55, 63, 74)
    Text    = [Drawing.Color]::FromArgb(226, 231, 236)
    Muted   = [Drawing.Color]::FromArgb(140, 151, 164)
    Ch1     = [Drawing.Color]::FromArgb(242, 165, 65)   # GTX 970
    Ch2     = [Drawing.Color]::FromArgb(79, 193, 201)   # GTX 750 Ti
    Ok      = [Drawing.Color]::FromArgb(128, 200, 140)
    Warn    = [Drawing.Color]::FromArgb(232, 112, 96)
    Button  = [Drawing.Color]::FromArgb(52, 61, 72)
    Active  = [Drawing.Color]::FromArgb(70, 82, 96)
}
function Get-Font([string]$Family, [single]$Size, [Drawing.FontStyle]$Style = 'Regular') {
    try { $f = New-Object Drawing.Font($Family, $Size, $Style); if ($f.Name -eq $Family) { return $f } } catch {}
    New-Object Drawing.Font('Segoe UI', $Size, $Style)
}
$F = @{
    Title  = Get-Font 'Bahnschrift' 20 'Bold'
    Big    = Get-Font 'Bahnschrift' 34 'Bold'
    Value  = Get-Font 'Bahnschrift' 15
    Ch     = Get-Font 'Bahnschrift' 14 'Bold'
    Label  = Get-Font 'Segoe UI' 9
    Body   = Get-Font 'Segoe UI' 10
    Button = Get-Font 'Segoe UI' 10 'Bold'
}

$script:Cards = @(
    [pscustomobject]@{ Key = 'GTX970';   Short = 'GTX 970';    Name = 'NVIDIA GeForce GTX 970';    DeviceId = '13C2'; Color = $C.Ch1; Pnp = $null; PnpStatus = '…'; Bus = $null; Hist = New-Object Collections.Generic.List[double]; M = @{} },
    [pscustomobject]@{ Key = 'GTX750TI'; Short = 'GTX 750 Ti'; Name = 'NVIDIA GeForce GTX 750 Ti'; DeviceId = '1380'; Color = $C.Ch2; Pnp = $null; PnpStatus = '…'; Bus = $null; Hist = New-Object Collections.Generic.List[double]; M = @{} }
)

# ---------- instância única ----------
$script:Mutex = $null
if (!$SelfTest) {
    $created = $false
    $script:Mutex = New-Object Threading.Mutex($true, 'Local\NexoGpuControl', [ref]$created)
    if (!$created) { [void][Windows.Forms.MessageBox]::Show('O NEXO GPU CONTROL já está aberto.', 'NEXO GPU CONTROL', 'OK', 'Information'); return }
}

# ---------- coleta (fora da thread da interface) ----------
$script:Fields = 'pci.device_id,pci.bus_id,utilization.gpu,utilization.memory,clocks.gr,clocks.mem,clocks.max.gr,clocks.max.mem,power.draw,power.limit,temperature.gpu,fan.speed,memory.used,memory.total,pcie.link.gen.gpucurrent,pcie.link.width.current,utilization.encoder,utilization.decoder,pstate,clocks_event_reasons.active'
$script:Collector = {
    param([bool]$WithPnp, [string]$Fields)
    $r = [ordered]@{ Ok = $true; Error = $null; Smi = @(); Pnp = $null; WithPnp = $WithPnp }
    try {
        $smi = (Get-Command nvidia-smi.exe -ErrorAction Stop).Source
        $out = & $smi "--query-gpu=$Fields" '--format=csv,noheader,nounits' 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
        $r.Smi = @($out | ForEach-Object { [string]$_ })
        if ($WithPnp) {
            $r.Pnp = @(Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE 'PCI\\VEN_10DE&DEV_13C2%' OR DeviceID LIKE 'PCI\\VEN_10DE&DEV_1380%'" -ErrorAction Stop |
                ForEach-Object { [pscustomobject]@{ DeviceID = [string]$_.DeviceID; Status = [string]$_.Status } })
        }
    } catch { $r.Ok = $false; $r.Error = $_.Exception.Message }
    [pscustomobject]$r
}

# Motivos de limitação de clock (bits documentados no NVML: clocks event reasons)
function Get-ThrottleText([string]$hex) {
    try { $v = [Convert]::ToUInt64(($hex -replace '^0x', ''), 16) } catch { return '—' }
    if ($v -eq 0) { return 'nenhuma' }
    $names = [ordered]@{ 0x1 = 'GPU ociosa'; 0x2 = 'clock de aplicação do driver'; 0x4 = 'limite de energia'; 0x8 = 'freio de hardware'; 0x10 = 'sincronização'; 0x20 = 'térmica (software)'; 0x40 = 'térmica (hardware)'; 0x80 = 'freio de energia (hardware)'; 0x100 = 'clock de exibição' }
    (@($names.Keys | Where-Object { $v -band $_ } | ForEach-Object { $names[$_] }) -join ', ')
}

# ---------- janela ----------
$form = New-Object Windows.Forms.Form
$form.Text = 'NEXO GPU CONTROL'; $form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object Drawing.Size(1140, 800); $form.MinimumSize = New-Object Drawing.Size(1156, 839)
$form.BackColor = $C.Bg; $form.ForeColor = $C.Text; $form.Font = $F.Body
$icon = Join-Path $script:AppRoot 'nexo-gpu-control.ico'
if (Test-Path $icon) { try { $form.Icon = New-Object Drawing.Icon($icon) } catch {} }

function New-Lbl([string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H, $Parent = $form, [string]$Align = 'TopLeft') {
    $l = New-Object Windows.Forms.Label; $l.Text = $Text; $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = [Drawing.Color]::Transparent
    $l.Location = New-Object Drawing.Point($X, $Y); $l.Size = New-Object Drawing.Size($W, $H); $l.TextAlign = $Align; $l.AutoEllipsis = $true
    $Parent.Controls.Add($l); $l
}
function New-Btn([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Parent = $form) {
    $b = New-Object Windows.Forms.Button; $b.Text = $Text; $b.Font = $F.Button
    $b.Location = New-Object Drawing.Point($X, $Y); $b.Size = New-Object Drawing.Size($W, $H)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 1; $b.FlatAppearance.BorderColor = $C.Grid
    $b.BackColor = $C.Button; $b.ForeColor = $C.Text; $b.Cursor = 'Hand'
    $Parent.Controls.Add($b); $b
}

# Cabeçalho
[void](New-Lbl 'NEXO GPU CONTROL' $F.Title $C.Text 24 16 360 36)
$engineLabel = New-Lbl 'Engine: procurando…' $F.Body $C.Muted 26 54 640 22
$runBtn = New-Btn 'Executar job nas duas placas' 856 18 260 50
$runBtn.BackColor = $C.Active; $runBtn.FlatAppearance.BorderColor = $C.Ch1

# Faixa de histórico (o destaque)
$scope = New-Object Windows.Forms.PictureBox
$scope.Location = New-Object Drawing.Point(24, 90); $scope.Size = New-Object Drawing.Size(1092, 200); $scope.BackColor = $C.Panel
$form.Controls.Add($scope)

# Painéis por placa
$script:Readouts = @{}
$metricDefs = @(
    @{ K = 'core';   L = 'Núcleo' },        @{ K = 'mem';    L = 'Memória' },
    @{ K = 'power';  L = 'Energia' },       @{ K = 'temp';   L = 'Temperatura' },
    @{ K = 'fan';    L = 'Ventoinha' },     @{ K = 'vram';   L = 'VRAM em uso' },
    @{ K = 'pcie';   L = 'Link PCIe' },     @{ K = 'pstate'; L = 'Estado de energia' },
    @{ K = 'enc';    L = 'Codificador de vídeo' }, @{ K = 'dec'; L = 'Decodificador de vídeo' },
    @{ K = 'bus';    L = 'Barramento PCI' }, @{ K = 'pnp';   L = 'Dispositivo no Windows' }
)
for ($i = 0; $i -lt 2; $i++) {
    $card = $script:Cards[$i]
    $p = New-Object Windows.Forms.Panel; $p.Location = New-Object Drawing.Point((24 + $i * 556), 306); $p.Size = New-Object Drawing.Size(536, 330); $p.BackColor = $C.Panel
    $form.Controls.Add($p)
    $stripe = New-Object Windows.Forms.Panel; $stripe.Location = New-Object Drawing.Point(0, 0); $stripe.Size = New-Object Drawing.Size(536, 4); $stripe.BackColor = $card.Color; $p.Controls.Add($stripe)
    $r = @{}
    $r.name = New-Lbl "Canal $($i + 1)   $($card.Short)" $F.Ch $card.Color 18 16 320 26 $p
    $r.util = New-Lbl '—' $F.Big $C.Text 18 44 170 56 $p
    $r.utilL = New-Lbl 'uso da GPU' $F.Label $C.Muted 22 100 160 18 $p
    $r.memutil = New-Lbl 'controlador de memória —' $F.Label $C.Muted 190 64 330 18 $p
    $r.throttle = New-Lbl 'limitação: —' $F.Label $C.Muted 190 84 330 32 $p
    for ($m = 0; $m -lt $metricDefs.Count; $m++) {
        $col = $m % 3; $row = [math]::Floor($m / 3)
        $x = 18 + $col * 172; $y = 130 + $row * 48
        [void](New-Lbl $metricDefs[$m].L $F.Label $C.Muted $x $y 165 16 $p)
        $r[$metricDefs[$m].K] = New-Lbl '—' $F.Value $C.Text $x ($y + 15) 165 26 $p
    }
    $script:Readouts[$card.Key] = $r
}

# Controle do scheduler
[void](New-Lbl 'Política do scheduler' $F.Ch $C.Text 24 652 300 24)
[void](New-Lbl 'Diz ao Engine quais placas ele pode usar. Não liga nem desliga placas no Windows e não muda jogos.' $F.Label $C.Muted 24 676 700 18)
$script:buttons = @{}
$modeDefs = @(
    @{ Key = 'DualOn';  Text = 'Duas placas';          Mode = 'DUAL_ON' },
    @{ Key = 'DualOff'; Text = 'Só a placa principal'; Mode = 'DUAL_OFF' },
    @{ Key = '970Only'; Text = 'Só GTX 970';           Mode = 'GTX970_ONLY' },
    @{ Key = '750Only'; Text = 'Só GTX 750 Ti';        Mode = 'GTX750TI_ONLY' }
)
for ($i = 0; $i -lt $modeDefs.Count; $i++) {
    $d = $modeDefs[$i]
    $b = New-Btn $d.Text (24 + $i * 186) 700 176 42
    $mode = $d.Mode; $b.Add_Click({ Invoke-ModeClick $mode }.GetNewClosure())
    $script:buttons[$d.Key] = $b
}
[void](New-Lbl 'Placa principal' $F.Label $C.Muted 780 700 120 16)
$primary = New-Object Windows.Forms.ComboBox; $primary.DropDownStyle = 'DropDownList'; $primary.FlatStyle = 'Flat'
$primary.Location = New-Object Drawing.Point(780, 716); $primary.Size = New-Object Drawing.Size(160, 26)
$primary.BackColor = $C.Button; $primary.ForeColor = $C.Text
[void]$primary.Items.Add('GTX 970'); [void]$primary.Items.Add('GTX 750 Ti'); $primary.SelectedIndex = 0
$form.Controls.Add($primary)
$policyLabel = New-Lbl 'Nenhuma política salva ainda.' $F.Label $C.Muted 24 750 920 18
$jobLabel = New-Lbl 'Nenhum job executado nesta sessão.' $F.Label $C.Muted 24 770 1092 20
$statusLabel = New-Lbl 'Telemetria: iniciando…' $F.Label $C.Muted 856 74 260 16 $form 'TopRight'

function Set-ModeHighlight([string]$Mode) {
    foreach ($d in $modeDefs) {
        $b = $script:buttons[$d.Key]
        if ($d.Mode -eq $Mode) { $b.BackColor = $C.Active; $b.FlatAppearance.BorderColor = $C.Text } else { $b.BackColor = $C.Button; $b.FlatAppearance.BorderColor = $C.Grid }
    }
}

# ---------- desenho da faixa de histórico ----------
$scope.Add_Paint({
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $w = $s.Width; $h = $s.Height; $left = 52; $right = 16; $top = 34; $bottom = 26
    $pw = $w - $left - $right; $ph = $h - $top - $bottom
    $gridPen = New-Object Drawing.Pen($C.Grid, 1)
    $lblBrush = New-Object Drawing.SolidBrush($C.Muted)
    foreach ($v in 0, 25, 50, 75, 100) {
        $y = $top + $ph - ($v / 100.0) * $ph
        $g.DrawLine($gridPen, $left, $y, $left + $pw, $y)
        $g.DrawString("$v%", $F.Label, $lblBrush, 10, $y - 8)
    }
    foreach ($sec in 0, 15, 30, 45, 60) {
        $x = $left + $pw - ($sec / 60.0) * $pw
        $g.DrawString($(if ($sec -eq 0) { 'agora' } else { "-$sec s" }), $F.Label, $lblBrush, $x - 16, $top + $ph + 6)
    }
    $g.DrawString('Uso da GPU nos últimos 60 segundos', $F.Body, (New-Object Drawing.SolidBrush($C.Text)), $left, 8)
    $lx = $left + $pw - 250
    foreach ($card in $script:Cards) {
        $g.FillRectangle((New-Object Drawing.SolidBrush($card.Color)), $lx, 13, 14, 4)
        $g.DrawString($card.Short, $F.Label, $lblBrush, $lx + 20, 6); $lx += 120
        $n = $card.Hist.Count
        if ($n -ge 2) {
            $pts = New-Object 'Collections.Generic.List[Drawing.PointF]'
            for ($k = 0; $k -lt $n; $k++) {
                $x = $left + $pw - (($n - 1 - $k) / ($script:HistoryLen - 1.0)) * $pw
                $y = $top + $ph - ([math]::Min(100, [math]::Max(0, $card.Hist[$k])) / 100.0) * $ph
                $pts.Add((New-Object Drawing.PointF([single]$x, [single]$y)))
            }
            $pen = New-Object Drawing.Pen($card.Color, 2.5); $g.DrawLines($pen, $pts.ToArray()); $pen.Dispose()
            $last = $pts[$pts.Count - 1]; $g.FillEllipse((New-Object Drawing.SolidBrush($card.Color)), $last.X - 4, $last.Y - 4, 8, 8)
        }
    }
    $gridPen.Dispose(); $lblBrush.Dispose()
})

# ---------- aplicar telemetria ----------
function Format-Num($v, [string]$unit, [int]$dec = 0) {
    $d = 0.0
    if ([double]::TryParse([string]$v, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return ("{0:N$dec} {1}" -f $d, $unit).Trim() }
    '—'
}
function Update-Telemetry($r) {
    if ($null -eq $r) { return }
    if (!$r.Ok) { $statusLabel.Text = "Telemetria indisponível: $($r.Error)"; $statusLabel.ForeColor = $C.Warn; return }
    if ($r.WithPnp -and $r.Pnp) {
        foreach ($card in $script:Cards) {
            $d = @($r.Pnp | Where-Object { $_.DeviceID -like "*DEV_$($card.DeviceId)*" }) | Select-Object -First 1
            if ($d) { $card.Pnp = $d.DeviceID; $card.PnpStatus = $d.Status } else { $card.PnpStatus = 'não encontrado' }
        }
    }
    foreach ($card in $script:Cards) {
        $p = $null
        foreach ($line in $r.Smi) { $parts = $line -split ',\s*'; if ($parts.Count -ge 20 -and $parts[0] -like "0x$($card.DeviceId)*") { $p = $parts; break } }
        $o = $script:Readouts[$card.Key]
        $o.pnp.Text = $card.PnpStatus; $o.pnp.ForeColor = if ($card.PnpStatus -eq 'OK') { $C.Ok } else { $C.Warn }
        if (!$p) { $o.util.Text = '—'; continue }
        $card.Bus = $p[1]
        $u = 0.0; [void][double]::TryParse($p[2], [ref]$u)
        $card.Hist.Add($u); while ($card.Hist.Count -gt $script:HistoryLen) { $card.Hist.RemoveAt(0) }
        $o.util.Text = "$([int]$u)%"
        $o.memutil.Text = "controlador de memória $($p[3])%"
        $o.core.Text = "$($p[4]) / $($p[6]) MHz"
        $o.mem.Text = "$($p[5]) / $($p[7]) MHz"
        $o.power.Text = "$(Format-Num $p[8] 'W' 0) de $(Format-Num $p[9] 'W' 0)"
        $o.temp.Text = "$($p[10]) °C"; $t = 0; [void][int]::TryParse($p[10], [ref]$t); $o.temp.ForeColor = if ($t -ge 80) { $C.Warn } else { $C.Text }
        $o.fan.Text = if ($p[11] -match '^\d') { "$($p[11])%" } else { 'sem leitura' }
        $o.vram.Text = "$($p[12]) / $($p[13]) MiB"
        $o.pcie.Text = "Gen$($p[14]) x$($p[15])"
        $o.enc.Text = "$($p[16])%"; $o.dec.Text = "$($p[17])%"
        $o.pstate.Text = $p[18]
        $o.bus.Text = ($p[1] -replace '^0000', '')
        $o.throttle.Text = "limitação: $(Get-ThrottleText $p[19])"
    }
    $scope.Invalidate()
    $statusLabel.Text = "ao vivo · $(Get-Date -Format HH:mm:ss)"; $statusLabel.ForeColor = $C.Muted
}

# ---------- Engine ----------
function Update-EngineLabel {
    if (!(Test-Path $script:EngineExe)) { $engineLabel.Text = 'Engine não instalado nesta pasta. Os botões só salvam a política.'; $engineLabel.ForeColor = $C.Warn; $runBtn.Enabled = $false; return }
    $runBtn.Enabled = $true
    if (Test-Path $script:EngineStatus) {
        try {
            $s = Get-Content -LiteralPath $script:EngineStatus -Raw | ConvertFrom-Json
            $engineLabel.Text = "Engine $($s.engineVersion): política $($s.policyMode) $(if ($s.acknowledgement -eq 'ACCEPTED') { 'aceita' } else { 'recusada' })$(if ($s.error) { " — $($s.error)" })"
            $engineLabel.ForeColor = if ($s.acknowledgement -eq 'ACCEPTED' -and !$s.error) { $C.Ok } else { $C.Warn }
            if ($s.lastRun) {
                $lr = $s.lastRun; $parts = @($s.plan | ForEach-Object { "$($_.key) $([math]::Round($_.share * 100))%" }) -join ' + '
                $cmp = if ($null -ne $lr.primaryAloneMedianMs) { " · principal sozinha $([math]::Round($lr.primaryAloneMedianMs, 2)) ms · $(if ($lr.reductionVsPrimaryPct -ge 0) { "$([math]::Round($lr.reductionVsPrimaryPct, 1))% mais rápido" } else { "$([math]::Round(-$lr.reductionVsPrimaryPct, 1))% mais lento" })" } else { '' }
                $jobLabel.Text = "Último job: $parts · distribuído $([math]::Round($lr.distributedMedianMs, 2)) ms$cmp · validação $($lr.validation)"
                $jobLabel.ForeColor = $C.Text
            }
        } catch { $engineLabel.Text = "Status do Engine ilegível: $($_.Exception.Message)"; $engineLabel.ForeColor = $C.Warn }
    } else { $engineLabel.Text = 'Engine instalado; ainda sem execução.'; $engineLabel.ForeColor = $C.Muted }
}
$script:EngineProc = $null
$runBtn.Add_Click({
    if ($script:EngineProc -and !$script:EngineProc.HasExited) { return }
    if (!(Test-Path $script:PolicyPath)) { $jobLabel.Text = 'Escolha uma política primeiro (por exemplo, Duas placas).'; $jobLabel.ForeColor = $C.Warn; return }
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $script:EngineExe; $psi.Arguments = "--run --reps 3 --sustain 10 --policy `"$script:PolicyPath`""; $psi.WorkingDirectory = $script:AppRoot
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardError = $true; $psi.RedirectStandardOutput = $true
        $script:EngineProc = [Diagnostics.Process]::Start($psi)
        $runBtn.Text = 'Executando… (cerca de 15 s)'; $runBtn.Enabled = $false
        $jobLabel.Text = 'Medindo e depois mantendo as duas placas ocupadas por 10 s. Veja as duas curvas subirem juntas no histórico.'; $jobLabel.ForeColor = $C.Text
    } catch { $jobLabel.Text = "Não consegui iniciar o Engine: $($_.Exception.Message)"; $jobLabel.ForeColor = $C.Warn }
})
function Step-Engine {
    if (!$script:EngineProc -or !$script:EngineProc.HasExited) { return }
    $code = $script:EngineProc.ExitCode
    $err = ''; try { $err = $script:EngineProc.StandardError.ReadToEnd() } catch {}
    $script:EngineProc.Dispose(); $script:EngineProc = $null
    $runBtn.Text = 'Executar job nas duas placas'; $runBtn.Enabled = $true
    Update-EngineLabel
    if ($code -ne 0) { $jobLabel.Text = "O job falhou: $($err.Trim())"; $jobLabel.ForeColor = $C.Warn }
}

# ---------- política ----------
function Save-Policy([string]$Mode) {
    $primaryKey = switch ($Mode) {
        'DUAL_ON' { 'GTX970' } 'DUAL_OFF' { if ($primary.SelectedIndex -eq 1) { 'GTX750TI' } else { 'GTX970' } }
        'GTX970_ONLY' { 'GTX970' } 'GTX750TI_ONLY' { 'GTX750TI' } default { throw "Modo inválido: $Mode" }
    }
    $allowed = if ($Mode -eq 'DUAL_ON') { @($script:Cards) } else { @($script:Cards | Where-Object Key -eq $primaryKey) }
    $policy = [ordered]@{
        schemaVersion = 1; updatedAt = (Get-Date).ToString('o'); mode = $Mode; distributionEnabled = ($Mode -eq 'DUAL_ON'); primaryGpu = $primaryKey
        allowedAdapters = @($allowed | ForEach-Object { [ordered]@{ name = $_.Name; deviceId = $_.DeviceId; pnpInstanceId = $_.Pnp; busId = $_.Bus } })
        hardwareDeviceChangesAllowed = $false; engineAcknowledgement = 'PENDING_ENGINE_INTEGRATION'
    }
    $folder = Split-Path -Parent $script:PolicyPath
    if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $temp = $script:PolicyPath + '.tmp.' + [guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp, ($policy | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($true)))
    try {
        if (Test-Path $script:PolicyPath) { [IO.File]::Replace($temp, $script:PolicyPath, $script:PolicyPath + '.bak.' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')) }
        else { [IO.File]::Move($temp, $script:PolicyPath) }
    } finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
    $leaf = Split-Path -Leaf $script:PolicyPath
    Get-ChildItem -LiteralPath $folder -Filter "$leaf.bak.*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -Skip $script:MaxBackups | Remove-Item -Force -ErrorAction SilentlyContinue
    $primary.SelectedIndex = if ($primaryKey -eq 'GTX750TI') { 1 } else { 0 }
    Set-ModeHighlight $Mode
    $policyLabel.Text = "Política salva às $(Get-Date -Format HH:mm:ss): $(($modeDefs | Where-Object Mode -eq $Mode).Text). O Engine usa esta escolha no próximo job."
    $policyLabel.ForeColor = $C.Muted
}
function Invoke-ModeClick([string]$Mode) {
    try { Save-Policy $Mode } catch { $policyLabel.Text = "Não consegui salvar a política: $($_.Exception.Message)"; $policyLabel.ForeColor = $C.Warn; if ($SelfTest) { throw } }
}
if (!$SelfTest -and (Test-Path $script:PolicyPath)) {
    try {
        $sp = Get-Content -LiteralPath $script:PolicyPath -Raw | ConvertFrom-Json
        $primary.SelectedIndex = if ($sp.primaryGpu -eq 'GTX750TI') { 1 } else { 0 }
        Set-ModeHighlight $sp.mode
        $policyLabel.Text = "Política atual: $(($modeDefs | Where-Object Mode -eq $sp.mode).Text), salva em $([datetime]::Parse($sp.updatedAt).ToString('dd\/MM HH:mm'))."
    } catch { $policyLabel.Text = "A política salva está ilegível: $($_.Exception.Message)"; $policyLabel.ForeColor = $C.Warn }
}

# ---------- self-test ----------
if ($SelfTest) {
    Update-Telemetry (& $script:Collector $true $script:Fields)
    $missing = @($script:Cards | Where-Object { !$_.Bus -or $_.PnpStatus -ne 'OK' })
    if ($missing.Count) { throw "Telemetria incompleta para: $(($missing | ForEach-Object Key) -join ', ')" }
    $blank = @(foreach ($card in $script:Cards) { foreach ($k in 'core', 'mem', 'power', 'temp', 'vram', 'pcie', 'pstate') { if ($script:Readouts[$card.Key][$k].Text -eq '—') { "$($card.Key).$k" } } })
    if ($blank.Count) { throw "Leituras vazias: $($blank -join ', ')" }
    $telemetry = @(foreach ($card in $script:Cards) { $o = $script:Readouts[$card.Key]; [pscustomobject]@{ GPU = $card.Name; Util = $o.util.Text; Core = $o.core.Text; Power = $o.power.Text; Temp = $o.temp.Text; Fan = $o.fan.Text; VRAM = $o.vram.Text; PCIe = $o.pcie.Text; PState = $o.pstate.Text; Throttle = $o.throttle.Text } })
    $onClick = [Windows.Forms.Control].GetMethod('OnClick', [Reflection.BindingFlags]'Instance,NonPublic')
    $results = @()
    $tests = @(
        @{ Key = 'DualOn'; Mode = 'DUAL_ON'; Allowed = 2; Dist = $true; Primary = 0 }, @{ Key = 'DualOff'; Mode = 'DUAL_OFF'; Allowed = 1; Dist = $false; Primary = 0 },
        @{ Key = '970Only'; Mode = 'GTX970_ONLY'; Allowed = 1; Dist = $false; Primary = 0 }, @{ Key = '750Only'; Mode = 'GTX750TI_ONLY'; Allowed = 1; Dist = $false; Primary = 0 },
        @{ Key = 'DualOff'; Mode = 'DUAL_OFF'; Allowed = 1; Dist = $false; Primary = 1; Name = 'DualOffSelected750Ti' }
    )
    foreach ($t in $tests) {
        $primary.SelectedIndex = $t.Primary
        $onClick.Invoke($script:buttons[$t.Key], @([EventArgs]::Empty))
        $s = Get-Content -LiteralPath $script:PolicyPath -Raw | ConvertFrom-Json
        $ok = $s.mode -eq $t.Mode -and @($s.allowedAdapters).Count -eq $t.Allowed -and $s.distributionEnabled -eq $t.Dist -and $s.hardwareDeviceChangesAllowed -eq $false -and @($s.allowedAdapters | Where-Object { !$_.pnpInstanceId -or !$_.busId }).Count -eq 0
        if ($t.Primary -eq 1) { $ok = $ok -and $s.primaryGpu -eq 'GTX750TI' -and $s.allowedAdapters[0].deviceId -eq '1380' }
        $name = if ($t.Name) { $t.Name } else { $t.Key }
        $results += [pscustomobject]@{ Button = $name; Mode = $s.mode; AllowedAdapters = @($s.allowedAdapters).Count; DistributionEnabled = $s.distributionEnabled; HardwareChangesAllowed = $s.hardwareDeviceChangesAllowed; Passed = $ok }
        if (!$ok) { throw "UI self-test falhou em $name" }
    }
    for ($i = 0; $i -lt 12; $i++) { $onClick.Invoke($script:buttons['DualOn'], @([EventArgs]::Empty)); Start-Sleep -Milliseconds 5 }
    $leaf = Split-Path -Leaf $script:PolicyPath
    $bak = @(Get-ChildItem -LiteralPath (Split-Path -Parent $script:PolicyPath) -Filter "$leaf.bak.*").Count
    $results += [pscustomobject]@{ Button = 'BackupLimit'; Mode = "$bak backups"; AllowedAdapters = $null; DistributionEnabled = $null; HardwareChangesAllowed = $false; Passed = ($bak -le $script:MaxBackups) }
    if ($bak -gt $script:MaxBackups) { throw "Backups acima do limite: $bak" }
    $resultPath = Join-Path (Split-Path $script:PolicyPath -Parent) 'ui-selftest-result.json'
    @{ Timestamp = (Get-Date).ToString('o'); Version = '2.0'; Result = 'PASS'; HardwareDevicesModified = $false; TelemetryReadOnly = $true; Telemetry = $telemetry; Tests = $results } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    $form.Dispose(); Write-Output "UI self-test PASS; policy=$script:PolicyPath; report=$resultPath"; return
}

# ---------- laço ----------
$script:Pool = [runspacefactory]::CreateRunspacePool(1, 1); $script:Pool.Open()
$script:Job = $null; $script:JobPs = $null; $script:NextSmi = [datetime]::MinValue; $script:NextPnp = [datetime]::MinValue
function Step-Telemetry {
    if ($script:Job) {
        if (!$script:Job.IsCompleted) { return }
        $result = $null
        try { $result = $script:JobPs.EndInvoke($script:Job) | Select-Object -First 1 } catch { $result = [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
        finally { $script:JobPs.Dispose(); $script:JobPs = $null; $script:Job = $null }
        Update-Telemetry $result
    }
    $now = Get-Date
    if ($now -ge $script:NextSmi) {
        $withPnp = $now -ge $script:NextPnp; if ($withPnp) { $script:NextPnp = $now.AddSeconds(30) }
        $script:NextSmi = $now.AddSeconds(1)
        $script:JobPs = [PowerShell]::Create(); $script:JobPs.RunspacePool = $script:Pool
        [void]$script:JobPs.AddScript($script:Collector.ToString()).AddArgument($withPnp).AddArgument($script:Fields)
        $script:Job = $script:JobPs.BeginInvoke()
    }
}
$timer = New-Object Windows.Forms.Timer; $timer.Interval = 250
$timer.Add_Tick({ try { Step-Telemetry; Step-Engine } catch { $statusLabel.Text = "Erro: $($_.Exception.Message)"; $statusLabel.ForeColor = $C.Warn } })
$form.Add_Shown({ Update-EngineLabel; Step-Telemetry; $timer.Start() })
$form.Add_FormClosed({
    $timer.Stop()
    try { if ($script:JobPs) { $script:JobPs.Stop(); $script:JobPs.Dispose() } } catch {}
    try { $script:Pool.Close(); $script:Pool.Dispose() } catch {}
    if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() } catch {}; $script:Mutex.Dispose() }
})
[void][Windows.Forms.Application]::Run($form)
