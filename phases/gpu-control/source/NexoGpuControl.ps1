[CmdletBinding()]
param([switch]$SelfTest, [string]$PolicyPath)
# NEXO GPU CONTROL v1.1 (2026-11-19)
# Mudanças em relação à v1.0:
#  - Telemetria roda num runspace em segundo plano; a janela não trava mais.
#    (Na v1.0, Get-PnpDevice levava 7–9 s por placa dentro do timer da interface.)
#  - Estado PnP consultado a cada 30 s via CIM filtrado; nvidia-smi a cada 3 s.
#  - Placas encontradas por DeviceId (13C2 / 1380), sem IDs de instância fixos no código.
#  - Uma instância por vez (mutex), para dois processos não gravarem a política juntos.
#  - Erros ao salvar aparecem na janela; mantém só os 10 backups mais recentes.
#  - Contrato da política (schemaVersion 1) inalterado.
# Somente leitura de hardware: não chama Disable/Enable-PnpDevice, pnputil, registro ou driver.
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Inicie com powershell.exe -STA -NoProfile -File NexoGpuControl.ps1' }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppRoot = $PSScriptRoot
if (!$PolicyPath) { $PolicyPath = Join-Path $PSScriptRoot 'scheduler-policy.json' }
$script:PolicyPath = [IO.Path]::GetFullPath($PolicyPath)
$script:MaxBackups = 10
$script:Cards = @(
    [pscustomobject]@{ Key = 'GTX970';   Name = 'NVIDIA GeForce GTX 970';    DeviceId = '13C2'; Pnp = $null; PnpStatus = 'consultando...'; Bus = $null },
    [pscustomobject]@{ Key = 'GTX750TI'; Name = 'NVIDIA GeForce GTX 750 Ti'; DeviceId = '1380'; Pnp = $null; PnpStatus = 'consultando...'; Bus = $null }
)

# ---------- instância única (a janela real; o self-test não disputa o mutex) ----------
$script:Mutex = $null
if (!$SelfTest) {
    $created = $false
    $script:Mutex = New-Object Threading.Mutex($true, 'Local\NexoGpuControl', [ref]$created)
    if (!$created) {
        [void][Windows.Forms.MessageBox]::Show('O NEXO GPU CONTROL já está aberto.', 'NEXO GPU CONTROL', 'OK', 'Information')
        return
    }
}

# ---------- coleta (roda fora da thread da interface) ----------
$script:Collector = {
    param([bool]$WithPnp)
    $r = [ordered]@{ Ok = $true; Error = $null; Smi = @(); Pnp = $null; WithPnp = $WithPnp }
    try {
        $smi = (Get-Command nvidia-smi.exe -ErrorAction Stop).Source
        $out = & $smi '--query-gpu=pci.device_id,name,pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total,pcie.link.gen.gpucurrent,pcie.link.width.current' '--format=csv,noheader,nounits' 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
        $r.Smi = @($out | ForEach-Object { [string]$_ })
        if ($WithPnp) {
            $r.Pnp = @(Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE 'PCI\\VEN_10DE&DEV_13C2%' OR DeviceID LIKE 'PCI\\VEN_10DE&DEV_1380%'" -ErrorAction Stop |
                ForEach-Object { [pscustomobject]@{ DeviceID = [string]$_.DeviceID; Status = [string]$_.Status } })
        }
    } catch { $r.Ok = $false; $r.Error = $_.Exception.Message }
    [pscustomobject]$r
}

# ---------- interface ----------
$form = New-Object Windows.Forms.Form
$form.Text = 'NEXO GPU CONTROL'; $form.StartPosition = 'CenterScreen'
$form.Size = New-Object Drawing.Size(880, 560); $form.MinimumSize = New-Object Drawing.Size(820, 520)
$form.BackColor = [Drawing.Color]::FromArgb(24, 28, 36); $form.ForeColor = [Drawing.Color]::White
$icon = Join-Path $script:AppRoot 'nexo-gpu-control.ico'
if (Test-Path $icon) { try { $form.Icon = New-Object Drawing.Icon($icon) } catch {} }

function New-Label([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Color) {
    $l = New-Object Windows.Forms.Label; $l.Text = $Text
    $l.Location = New-Object Drawing.Point($X, $Y); $l.Size = New-Object Drawing.Size($W, $H); $l.ForeColor = $Color
    $form.Controls.Add($l); $l
}
$title = New-Label 'NEXO GPU CONTROL' 20 16 500 40 ([Drawing.Color]::White)
$title.Font = New-Object Drawing.Font('Segoe UI', 20, [Drawing.FontStyle]::Bold)
$engineLabel = New-Label 'NEXO GPU ENGINE: procurando...' 22 62 820 25 ([Drawing.Color]::Gold)
[void](New-Label 'Controle lógico do scheduler. As placas e saídas de vídeo permanecem habilitadas; nenhum dispositivo PnP é alterado.' 22 88 820 35 ([Drawing.Color]::LightGreen))

$grid = New-Object Windows.Forms.DataGridView
$grid.Location = New-Object Drawing.Point(22, 135); $grid.Size = New-Object Drawing.Size(820, 145)
$grid.ReadOnly = $true; $grid.AllowUserToAddRows = $false; $grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false; $grid.AutoSizeColumnsMode = 'Fill'; $grid.SelectionMode = 'FullRowSelect'
$grid.BackgroundColor = [Drawing.Color]::FromArgb(35, 40, 50); $grid.ForeColor = [Drawing.Color]::Black
foreach ($c in @('GPU', 'PnP status', 'PCI bus', 'GPU %', 'Temp °C', 'VRAM used / total', 'PCIe link')) { [void]$grid.Columns.Add($c, $c) }
foreach ($card in $script:Cards) { [void]$grid.Rows.Add($card.Name, $card.PnpStatus, '—', '—', '—', '—', '—') }
$form.Controls.Add($grid)

[void](New-Label 'GPU principal (para DUAL OFF):' 22 296 250 24 ([Drawing.Color]::White))
$primary = New-Object Windows.Forms.ComboBox; $primary.DropDownStyle = 'DropDownList'
$primary.Location = New-Object Drawing.Point(275, 292); $primary.Size = New-Object Drawing.Size(250, 28)
[void]$primary.Items.Add('GTX 970'); [void]$primary.Items.Add('GTX 750 Ti'); $primary.SelectedIndex = 0
$form.Controls.Add($primary)

$script:buttons = @{}
function Add-ModeButton([string]$Key, [string]$Text, [int]$X, [int]$Y, [int]$W, [string]$Mode) {
    $b = New-Object Windows.Forms.Button; $b.Text = $Text
    $b.Location = New-Object Drawing.Point($X, $Y); $b.Size = New-Object Drawing.Size($W, 48)
    $b.FlatStyle = 'Flat'; $b.BackColor = [Drawing.Color]::FromArgb(55, 75, 105); $b.ForeColor = [Drawing.Color]::White
    $b.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $b.Add_Click({ Invoke-ModeClick $Mode }.GetNewClosure())
    $form.Controls.Add($b); $script:buttons[$Key] = $b
}
Add-ModeButton 'DualOn' 'DUAL GPU ON' 22 340 190 'DUAL_ON'
Add-ModeButton 'DualOff' 'DUAL GPU OFF' 225 340 190 'DUAL_OFF'
Add-ModeButton '970Only' 'GTX 970 ONLY' 428 340 190 'GTX970_ONLY'
Add-ModeButton '750Only' 'GTX 750 Ti ONLY' 631 340 211 'GTX750TI_ONLY'

$policyLabel = New-Label 'Scheduler policy: nenhum perfil salvo.' 22 405 820 28 ([Drawing.Color]::LightSkyBlue)
[void](New-Label 'Quando o NEXO GPU ENGINE estiver integrado, ele consumirá a política local. No estado atual, os botões salvam somente a intenção; nenhuma tarefa GPU é redistribuída.' 22 438 820 42 ([Drawing.Color]::Gainsboro))
$statusLabel = New-Label 'Telemetria: iniciando...' 22 488 820 24 ([Drawing.Color]::Silver)

function Get-EngineText {
    if (Test-Path (Join-Path $script:AppRoot 'NexoGpuEngine.exe')) { 'NEXO GPU ENGINE: executável encontrado; protocolo ainda sem ACK.' }
    else { 'NEXO GPU ENGINE: NÃO ENCONTRADO — política local apenas, sem distribuição real.' }
}

# ---------- aplicar telemetria na grade (thread da interface, rápido) ----------
function Update-Telemetry($r) {
    if ($null -eq $r) { return }
    if (!$r.Ok) {
        $statusLabel.Text = "Telemetria indisponível ($(Get-Date -Format HH:mm:ss)): $($r.Error)"
        $statusLabel.ForeColor = [Drawing.Color]::Salmon
        return
    }
    if ($r.WithPnp -and $r.Pnp) {
        foreach ($card in $script:Cards) {
            $d = @($r.Pnp | Where-Object { $_.DeviceID -like "*DEV_$($card.DeviceId)*" }) | Select-Object -First 1
            if ($d) { $card.Pnp = $d.DeviceID; $card.PnpStatus = $d.Status } else { $card.PnpStatus = 'NOT_FOUND' }
        }
    }
    for ($i = 0; $i -lt $script:Cards.Count; $i++) {
        $card = $script:Cards[$i]
        $p = $null
        foreach ($line in $r.Smi) {
            $parts = $line -split ',\s*'
            if ($parts.Count -ge 9 -and $parts[0] -like "0x$($card.DeviceId)*") { $p = $parts; break }
        }
        $row = $grid.Rows[$i]
        $row.Cells[1].Value = $card.PnpStatus
        if ($p) {
            $card.Bus = $p[2]
            $row.Cells[2].Value = $p[2]; $row.Cells[3].Value = $p[3]; $row.Cells[4].Value = $p[4]
            $row.Cells[5].Value = "$($p[5]) / $($p[6]) MiB"; $row.Cells[6].Value = "Gen$($p[7]) x$($p[8])"
        } else {
            foreach ($k in 2..6) { $row.Cells[$k].Value = 'N/A' }
        }
    }
    $engineLabel.Text = Get-EngineText; $engineLabel.ForeColor = [Drawing.Color]::Gold
    $statusLabel.Text = "Telemetria somente leitura, atualizada às $(Get-Date -Format HH:mm:ss) (GPU a cada 3 s, PnP a cada 30 s)."
    $statusLabel.ForeColor = [Drawing.Color]::Silver
}

# ---------- política ----------
function Save-Policy([string]$Mode) {
    $primaryKey = switch ($Mode) {
        'DUAL_ON'       { 'GTX970' }
        'DUAL_OFF'      { if ($primary.SelectedIndex -eq 1) { 'GTX750TI' } else { 'GTX970' } }
        'GTX970_ONLY'   { 'GTX970' }
        'GTX750TI_ONLY' { 'GTX750TI' }
        default         { throw "Modo inválido: $Mode" }
    }
    $allowed = if ($Mode -eq 'DUAL_ON') { @($script:Cards) } else { @($script:Cards | Where-Object Key -eq $primaryKey) }
    $policy = [ordered]@{
        schemaVersion = 1
        updatedAt = (Get-Date).ToString('o')
        mode = $Mode
        distributionEnabled = ($Mode -eq 'DUAL_ON')
        primaryGpu = $primaryKey
        allowedAdapters = @($allowed | ForEach-Object { [ordered]@{ name = $_.Name; deviceId = $_.DeviceId; pnpInstanceId = $_.Pnp; busId = $_.Bus } })
        hardwareDeviceChangesAllowed = $false
        engineAcknowledgement = 'PENDING_ENGINE_INTEGRATION'
    }
    $folder = Split-Path -Parent $script:PolicyPath
    if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $temp = $script:PolicyPath + '.tmp.' + [guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp, ($policy | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($true)))
    try {
        if (Test-Path $script:PolicyPath) {
            $backup = $script:PolicyPath + '.bak.' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
            [IO.File]::Replace($temp, $script:PolicyPath, $backup)   # troca atômica no mesmo volume
        } else {
            [IO.File]::Move($temp, $script:PolicyPath)
        }
    } finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
    $leaf = Split-Path -Leaf $script:PolicyPath
    Get-ChildItem -LiteralPath $folder -Filter "$leaf.bak.*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip $script:MaxBackups |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $primary.SelectedIndex = if ($primaryKey -eq 'GTX750TI') { 1 } else { 0 }
    $policyLabel.Text = "Política $Mode salva às $(Get-Date -Format HH:mm:ss) em $script:PolicyPath"
    $policyLabel.ForeColor = [Drawing.Color]::LightSkyBlue
    $engineLabel.Text = Get-EngineText; $engineLabel.ForeColor = [Drawing.Color]::Gold
}
function Invoke-ModeClick([string]$Mode) {
    try { Save-Policy $Mode }
    catch {
        $policyLabel.Text = "Falha ao salvar a política ($Mode): $($_.Exception.Message)"
        $policyLabel.ForeColor = [Drawing.Color]::Salmon
        if ($SelfTest) { throw }
    }
}

# ---------- carregar política existente ----------
if (!$SelfTest -and (Test-Path $script:PolicyPath)) {
    try {
        $savedPolicy = Get-Content -LiteralPath $script:PolicyPath -Raw | ConvertFrom-Json
        $primary.SelectedIndex = if ($savedPolicy.primaryGpu -eq 'GTX750TI') { 1 } else { 0 }
        $policyLabel.Text = "Política carregada: $($savedPolicy.mode) — $($savedPolicy.updatedAt)"
    } catch { $policyLabel.Text = "Política existente inválida: $($_.Exception.Message)"; $policyLabel.ForeColor = [Drawing.Color]::Salmon }
}

# ---------- self-test (síncrono, sem janela visível) ----------
if ($SelfTest) {
    Update-Telemetry (& $script:Collector $true)
    $missing = @($script:Cards | Where-Object { !$_.Bus -or $_.PnpStatus -eq 'NOT_FOUND' })
    if ($missing.Count) { throw "Telemetria incompleta para: $(($missing | ForEach-Object Key) -join ', ')" }
    $telemetry = @(foreach ($r in $grid.Rows) { [pscustomobject]@{ GPU = $r.Cells[0].Value; PnP = $r.Cells[1].Value; Bus = $r.Cells[2].Value; Utilization = $r.Cells[3].Value; Temperature = $r.Cells[4].Value; VRAM = $r.Cells[5].Value; PCIe = $r.Cells[6].Value } })
    $onClick = [Windows.Forms.Control].GetMethod('OnClick', [Reflection.BindingFlags]'Instance,NonPublic')
    $results = @()
    $tests = @(
        @{ Key = 'DualOn';  Mode = 'DUAL_ON';       Allowed = 2; Dist = $true;  Primary = 0 },
        @{ Key = 'DualOff'; Mode = 'DUAL_OFF';      Allowed = 1; Dist = $false; Primary = 0 },
        @{ Key = '970Only'; Mode = 'GTX970_ONLY';   Allowed = 1; Dist = $false; Primary = 0 },
        @{ Key = '750Only'; Mode = 'GTX750TI_ONLY'; Allowed = 1; Dist = $false; Primary = 0 },
        @{ Key = 'DualOff'; Mode = 'DUAL_OFF';      Allowed = 1; Dist = $false; Primary = 1; Name = 'DualOffSelected750Ti' }
    )
    foreach ($t in $tests) {
        $primary.SelectedIndex = $t.Primary
        $onClick.Invoke($script:buttons[$t.Key], @([EventArgs]::Empty))
        $s = Get-Content -LiteralPath $script:PolicyPath -Raw | ConvertFrom-Json
        $ok = $s.mode -eq $t.Mode -and @($s.allowedAdapters).Count -eq $t.Allowed -and $s.distributionEnabled -eq $t.Dist -and $s.hardwareDeviceChangesAllowed -eq $false -and
              @($s.allowedAdapters | Where-Object { !$_.pnpInstanceId -or !$_.busId }).Count -eq 0
        if ($t.Primary -eq 1) { $ok = $ok -and $s.primaryGpu -eq 'GTX750TI' -and $s.allowedAdapters[0].deviceId -eq '1380' }
        $name = if ($t.Name) { $t.Name } else { $t.Key }
        $results += [pscustomobject]@{ Button = $name; Mode = $s.mode; AllowedAdapters = @($s.allowedAdapters).Count; DistributionEnabled = $s.distributionEnabled; HardwareChangesAllowed = $s.hardwareDeviceChangesAllowed; Passed = $ok }
        if (!$ok) { throw "UI self-test falhou em $name" }
    }
    # backups limitados
    for ($i = 0; $i -lt 12; $i++) { $onClick.Invoke($script:buttons['DualOn'], @([EventArgs]::Empty)); Start-Sleep -Milliseconds 5 }
    $leaf = Split-Path -Leaf $script:PolicyPath
    $bak = @(Get-ChildItem -LiteralPath (Split-Path -Parent $script:PolicyPath) -Filter "$leaf.bak.*").Count
    $results += [pscustomobject]@{ Button = 'BackupLimit'; Mode = "$bak backups"; AllowedAdapters = $null; DistributionEnabled = $null; HardwareChangesAllowed = $false; Passed = ($bak -le $script:MaxBackups) }
    if ($bak -gt $script:MaxBackups) { throw "Backups acima do limite: $bak" }
    $resultPath = Join-Path (Split-Path $script:PolicyPath -Parent) 'ui-selftest-result.json'
    @{ Timestamp = (Get-Date).ToString('o'); Version = '1.1'; Result = 'PASS'; HardwareDevicesModified = $false; TelemetryReadOnly = $true; Telemetry = $telemetry; Tests = $results } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    $form.Dispose()
    Write-Output "UI self-test PASS; policy=$script:PolicyPath; report=$resultPath"
    return
}

# ---------- laço da janela: timer de 500 ms só verifica resultados prontos ----------
$script:Pool = [runspacefactory]::CreateRunspacePool(1, 1); $script:Pool.Open()
$script:Job = $null; $script:JobPs = $null
$script:NextSmi = [datetime]::MinValue; $script:NextPnp = [datetime]::MinValue
function Step-Telemetry {
    if ($script:Job) {
        if (!$script:Job.IsCompleted) { return }
        $result = $null
        try { $result = $script:JobPs.EndInvoke($script:Job) | Select-Object -First 1 }
        catch { $result = [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
        finally { $script:JobPs.Dispose(); $script:JobPs = $null; $script:Job = $null }
        Update-Telemetry $result
    }
    $now = Get-Date
    if ($now -ge $script:NextSmi) {
        $withPnp = $now -ge $script:NextPnp
        if ($withPnp) { $script:NextPnp = $now.AddSeconds(30) }
        $script:NextSmi = $now.AddSeconds(3)
        $script:JobPs = [PowerShell]::Create(); $script:JobPs.RunspacePool = $script:Pool
        [void]$script:JobPs.AddScript($script:Collector.ToString()).AddArgument($withPnp)
        $script:Job = $script:JobPs.BeginInvoke()
    }
}
$timer = New-Object Windows.Forms.Timer; $timer.Interval = 500
$timer.Add_Tick({ try { Step-Telemetry } catch { $statusLabel.Text = "Erro na telemetria: $($_.Exception.Message)"; $statusLabel.ForeColor = [Drawing.Color]::Salmon } })
$form.Add_Shown({ $engineLabel.Text = Get-EngineText; Step-Telemetry; $timer.Start() })
$form.Add_FormClosed({
    $timer.Stop()
    try { if ($script:JobPs) { $script:JobPs.Stop(); $script:JobPs.Dispose() } } catch {}
    try { $script:Pool.Close(); $script:Pool.Dispose() } catch {}
    if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() } catch {}; $script:Mutex.Dispose() }
})
[void][Windows.Forms.Application]::Run($form)
