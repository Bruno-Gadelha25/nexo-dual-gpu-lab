param(
  [int]$IntervalSeconds = 30,
  [int]$MaxDays = 5
)
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Logs = Join-Path $Root 'logs'
$StopFile = Join-Path $Root 'STOP'
$PidFile = Join-Path $Root 'monitor.pid'
$Start = if (Test-Path -LiteralPath (Join-Path $Root 'campaign-start.txt')) { [datetime](Get-Content -LiteralPath (Join-Path $Root 'campaign-start.txt') -Raw) } else { Get-Date }
$End = $Start.AddDays([Math]::Min(5,[Math]::Max(1,$MaxDays)))
$LastEventCheck = $Start.AddSeconds(-30)
$SeenEvents = @{}
$LastProcessSnapshot = [datetime]::MinValue
$DayDir = ''
$Nvsmi = Join-Path $env:WINDIR 'System32\nvidia-smi.exe'
$GpuFields = 'name,temperature.gpu,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,clocks.current.graphics,clocks.current.memory,fan.speed,power.draw,power.limit,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max'
$GpuQuery = "--query-gpu=$GpuFields --format=csv"
function Add-CsvRow([string]$Path,[object]$Row) {
  if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 0) { $Row | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Add-Content -LiteralPath $Path -Encoding UTF8 }
  else { $Row | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 }
}
function Add-SystemRow([string]$Path,[object]$Row) {
  Add-CsvRow $Path ([pscustomobject][ordered]@{timestamp=$Row.timestamp;type=$Row.type;source=$Row.source;event_id=$Row.event_id;level=$Row.level;message=$Row.message;record_id=$Row.record_id;event_time=$Row.event_time;uptime_seconds=$Row.uptime_seconds;disk_readwrite_bytes_sec=$Row.disk_readwrite_bytes_sec;disk_read_bytes_sec=$Row.disk_read_bytes_sec;disk_write_bytes_sec=$Row.disk_write_bytes_sec;disk_busy_percent=$Row.disk_busy_percent;disk_E_free_bytes=$Row.disk_E_free_bytes;disk_E_size_bytes=$Row.disk_E_size_bytes})
}
function Num([object]$Value) {
  if ($null -eq $Value) { return $null }
  $s=([string]$Value).Trim()
  if (!$s -or $s -match '^(N/A|NA|Not Supported|\[N/A\]|\[Not Supported\]|Unknown)$') { return $null }
  $s=$s -replace '\s*(MiB|MHz|W|%|C)$','' -replace '\[|\]','' -replace ',',''
  $d=0.0
  if ([double]::TryParse($s,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$d)) { return $d }
  return $null
}
function Get-DayFiles([string]$DayPath) {
  foreach($name in 'gpus-telemetry.csv','cpu-telemetry.csv','system-events.csv','gpu-processes.csv') {
    $p=Join-Path $DayPath $name
    if (!(Test-Path -LiteralPath $p)) { New-Item -ItemType File -Path $p | Out-Null }
  }
}
function SafeText([object]$v) { if ($null -eq $v) { return '' }; return ([string]$v -replace '[\r\n]+',' ').Trim() }
function Get-GpuSamples([string]$Stamp) {
  $out = & $Nvsmi "--query-gpu=$GpuFields" '--format=csv,noheader,nounits' 2>$null
  if ($LASTEXITCODE -ne 0 -or !$out) { Add-SystemRow (Join-Path $DayDir 'system-events.csv') ([pscustomobject]@{timestamp=$Stamp;type='collector_error';source='nvidia-smi';event_id='';level='';message='Consulta de telemetria NVIDIA falhou'}) ; return }
  $parsed = foreach($line in $out) {
    $v=$line -split ',\s*'
    if($v.Count -ge 16) { [pscustomobject]@{name=$v[0];temperature=$v[1];gpuutil=$v[2];memutil=$v[3];total=$v[4];used=$v[5];free=$v[6];gpuclock=$v[7];memclock=$v[8];fan=$v[9];power=$v[10];powerlimit=$v[11];pcigen=$v[12];pcimax=$v[13];pciewidth=$v[14];pciewidthmax=$v[15]} }
  }
  $parsed=@($parsed)
  $script:LastGpuRows=$parsed
  foreach($g in $parsed) {
    Add-CsvRow (Join-Path $DayDir 'gpus-telemetry.csv') ([pscustomobject]@{
      timestamp=$Stamp; gpu=$g.name; temperature_c=Num $g.temperature; gpu_util_percent=Num $g.gpuutil; memory_util_percent=Num $g.memutil; vram_total_mib=Num $g.total; vram_used_mib=Num $g.used; vram_free_mib=Num $g.free; gpu_clock_mhz=Num $g.gpuclock; memory_clock_mhz=Num $g.memclock; fan_percent=Num $g.fan; power_w=Num $g.power; power_limit_w=Num $g.powerlimit; pcie_gen_current=Num $g.pcigen; pcie_gen_max=Num $g.pcimax; pcie_width_current=Num $g.pciewidth; pcie_width_max=Num $g.pciewidthmax
    })
  }
}
function Get-CpuSample([string]$Stamp) {
  $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
  $cpu=Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
  $counter=Get-Counter '\Processor(*)\% Processor Time' -ErrorAction SilentlyContinue
  $cores=@($counter.CounterSamples)
  if (!$cores.Count -and $cpu) { $cores=@([pscustomobject]@{InstanceName='_Total';CookedValue=$cpu.LoadPercentage}) }
  foreach($c in $cores) {
    $name=$c.InstanceName
    $temp=$null
    Add-CsvRow (Join-Path $DayDir 'cpu-telemetry.csv') ([pscustomobject]@{
      timestamp=$Stamp; logical_processor=$name; cpu_util_percent=Num $c.CookedValue; cpu_clock_mhz=if($cpu){$cpu.CurrentClockSpeed}else{$null}; cpu_max_clock_mhz=if($cpu){$cpu.MaxClockSpeed}else{$null}; cpu_temperature_c=$temp; cpu_temp_sensor='unavailable'; ram_total_mib=if($os){[Math]::Round($os.TotalVisibleMemorySize/1024,1)}else{$null}; ram_free_mib=if($os){[Math]::Round($os.FreePhysicalMemory/1024,1)}else{$null}; ram_used_mib=if($os){[Math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1024,1)}else{$null}; uptime_seconds=if($os){[Math]::Round(((Get-Date)-$os.LastBootUpTime).TotalSeconds,0)}else{$null}
    })
  }
}
function Get-SystemSample([string]$Stamp) {
  $drive=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='E:'" -ErrorAction SilentlyContinue
  $disk=$null; $read=$null; $write=$null; $busy=$null
  $diskCounter=Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec','\PhysicalDisk(_Total)\Disk Read Bytes/sec','\PhysicalDisk(_Total)\Disk Write Bytes/sec','\PhysicalDisk(_Total)\% Disk Time' -ErrorAction SilentlyContinue
  foreach($c in @($diskCounter.CounterSamples)) {
    if($c.Path -match 'Disk Read Bytes/sec') { $read=$c.CookedValue }
    elseif($c.Path -match 'Disk Write Bytes/sec') { $write=$c.CookedValue }
    elseif($c.Path -match '% Disk Time') { $busy=$c.CookedValue }
    elseif($c.Path -match 'Disk Bytes/sec') { $disk=$c.CookedValue }
  }
  $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
  Add-SystemRow (Join-Path $DayDir 'system-events.csv') ([pscustomobject]@{timestamp=$Stamp;type='system_sample';source='Windows';event_id='';level='';message='';uptime_seconds=if($os){[Math]::Round(((Get-Date)-$os.LastBootUpTime).TotalSeconds,0)}else{$null};disk_readwrite_bytes_sec=Num $disk;disk_read_bytes_sec=Num $read;disk_write_bytes_sec=Num $write;disk_busy_percent=Num $busy;disk_E_free_bytes=if($drive){$drive.FreeSpace}else{$null};disk_E_size_bytes=if($drive){$drive.Size}else{$null}})
  $since=$LastEventCheck.AddSeconds(-1)
  $events=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since} -MaxEvents 250 -ErrorAction SilentlyContinue
  foreach($e in $events) {
    if (($e.ProviderName -match 'Display|nvlddmkm|WHEA|Kernel-PnP|Disk|Resource-Exhaustion') -and ($e.Level -le 3 -or $e.Id -eq 4101)) {
      $key="$($e.ProviderName)|$($e.RecordId)"
      if (!$SeenEvents.ContainsKey($key)) {
        $SeenEvents[$key]=$true
        Add-SystemRow (Join-Path $DayDir 'system-events.csv') ([pscustomobject]@{timestamp=$Stamp;type='windows_event';source=$e.ProviderName;event_id=$e.Id;level=$e.LevelDisplayName;message=SafeText $e.Message;record_id=$e.RecordId;event_time=$e.TimeCreated.ToString('o')})
      }
    }
  }
  $script:LastEventCheck=Get-Date
  if (((Get-Date)-$LastProcessSnapshot).TotalMinutes -ge 60) {
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
      Add-SystemRow (Join-Path $DayDir 'system-events.csv') ([pscustomobject]@{timestamp=$Stamp;type='process_snapshot';source='Windows';event_id='';level='';message=("name={0};pid={1};cpu_s={2};working_set_bytes={3}" -f $_.ProcessName,$_.Id,$_.CPU,$_.WorkingSet64)})
    }
    $script:LastProcessSnapshot=Get-Date
  }
}
function Get-GpuProcessSample([string]$Stamp) {
  $lines=& $Nvsmi '--query-compute-apps=pid,process_name,used_memory' '--format=csv,noheader' 2>$null
  foreach($line in $lines) {
    if ($line -match '^\s*(\d+)\s*,\s*(.*?)\s*,\s*(.*?)\s*$') {
      Add-CsvRow (Join-Path $DayDir 'gpu-processes.csv') ([pscustomobject]@{timestamp=$Stamp;pid=$matches[1];process_name=$matches[2];gpu_memory_mib=Num $matches[3]})
    }
  }
}
function Percentile([double[]]$Values,[double]$P) {
  if (!$Values -or !$Values.Count) { return $null }
  $sorted=@($Values|Sort-Object); $idx=[Math]::Max(0,[Math]::Ceiling($P*$sorted.Count)-1); return [Math]::Round($sorted[$idx],3)
}
function SampleStdDev([double[]]$Values) {
  if (!$Values -or $Values.Count -lt 2) { return $null }
  $avg=($Values|Measure-Object -Average).Average; $sum=0.0
  foreach($v in $Values) { $d=[double]$v-[double]$avg; $sum+=$d*$d }
  return [Math]::Sqrt($sum/($Values.Count-1))
}
function Corr([double[]]$X,[double[]]$Y) {
  if (!$X -or $X.Count -lt 3 -or $X.Count -ne $Y.Count) { return $null }
  $mx=($X|Measure-Object -Average).Average; $my=($Y|Measure-Object -Average).Average; $a=0.0;$bx=0.0;$by=0.0
  for($i=0;$i -lt $X.Count;$i++){ $dx=$X[$i]-$mx;$dy=$Y[$i]-$my;$a+=$dx*$dy;$bx+=$dx*$dx;$by+=$dy*$dy }
  if($bx -eq 0 -or $by -eq 0){return $null};return [Math]::Round($a/[Math]::Sqrt($bx*$by),4)
}
function Write-FinalReports([string]$Reason) {
  $gpuRows=@(Get-ChildItem $Logs -Directory | Where-Object Name -Match '^\d{4}-\d{2}-\d{2}$' | ForEach-Object { Import-Csv (Join-Path $_.FullName 'gpus-telemetry.csv') -ErrorAction SilentlyContinue })
  $cpuRows=@(Get-ChildItem $Logs -Directory | Where-Object Name -Match '^\d{4}-\d{2}-\d{2}$' | ForEach-Object { Import-Csv (Join-Path $_.FullName 'cpu-telemetry.csv') -ErrorAction SilentlyContinue })
  $stats=New-Object System.Collections.Generic.List[object]
  foreach($row in $gpuRows){foreach($field in 'temperature_c','gpu_util_percent','memory_util_percent','vram_used_mib','gpu_clock_mhz','memory_clock_mhz','fan_percent','power_w','pcie_gen_current','pcie_width_current'){ $v=Num $row.$field;if($null -ne $v){$stats.Add([pscustomobject]@{device=$row.gpu;metric=$field;value=$v})}}}
  foreach($row in $cpuRows){foreach($field in 'cpu_util_percent','cpu_clock_mhz','ram_used_mib','uptime_seconds'){ $v=Num $row.$field;if($null -ne $v){$stats.Add([pscustomobject]@{device=('CPU/'+$row.logical_processor);metric=$field;value=$v})}}}
  $systemRows=@(Get-ChildItem $Logs -Directory | Where-Object Name -Match '^\d{4}-\d{2}-\d{2}$' | ForEach-Object { Import-Csv (Join-Path $_.FullName 'system-events.csv') -ErrorAction SilentlyContinue } | Where-Object type -eq 'system_sample')
  foreach($row in $systemRows){foreach($field in 'disk_readwrite_bytes_sec','disk_read_bytes_sec','disk_write_bytes_sec','disk_busy_percent'){ $v=Num $row.$field;if($null -ne $v){$stats.Add([pscustomobject]@{device='System';metric=$field;value=$v})}};$v=Num $row.disk_E_free_bytes;if($null -ne $v){$stats.Add([pscustomobject]@{device='System';metric='disk_E_free_gib';value=($v/1GB)})};$v=Num $row.uptime_seconds;if($null -ne $v){$stats.Add([pscustomobject]@{device='System';metric='uptime_seconds';value=$v})}}
  $metricStats=foreach($g in ($stats|Group-Object device,metric)) { $vals=@($g.Group|ForEach-Object {[double]$_.value});$m=$vals|Measure-Object -Average -Minimum -Maximum;$sd=SampleStdDev $vals;$cv=if($m.Average -and $null -ne $sd){[Math]::Round(100*$sd/[Math]::Abs($m.Average),2)}else{$null};$variability=if($null -ne $cv -and $cv -ge 10){'elevated (CV >= 10%)'}else{'below heuristic threshold'};[pscustomobject]@{device=$g.Group[0].device;metric=$g.Group[0].metric;samples=$vals.Count;mean=[Math]::Round($m.Average,3);median=Percentile $vals 0.5;min=[Math]::Round($m.Minimum,3);max=[Math]::Round($m.Maximum,3);stddev=if($null -ne $sd){[Math]::Round($sd,3)}else{$null};cv_percent=$cv;variability_flag=$variability;p50=Percentile $vals .5;p95=Percentile $vals .95;p99=Percentile $vals .99} }
  $metricStats | Export-Csv (Join-Path $Root 'metric-statistics.csv') -NoTypeInformation -Encoding UTF8
  $corrRows=@()
  foreach($gpu in @('NVIDIA GeForce GTX 970','NVIDIA GeForce GTX 750 Ti')) {
    $r=@($gpuRows|Where-Object gpu -eq $gpu)
    foreach($pair in @(@('temperature_c','gpu_clock_mhz'),@('temperature_c','gpu_util_percent'),@('gpu_util_percent','gpu_clock_mhz'))) {
      $valid=@($r|Where-Object {$null -ne (Num $_.($pair[0])) -and $null -ne (Num $_.($pair[1]))})
      $x=@($valid|ForEach-Object {[double](Num $_.($pair[0]))});$y=@($valid|ForEach-Object {[double](Num $_.($pair[1]))})
      $corrRows+=,[pscustomobject]@{device=$gpu;x=$pair[0];y=$pair[1];samples=$valid.Count;pearson_r=Corr $x $y;note='Correlação descritiva; não indica causalidade'}
    }
  }
  $corrRows | Export-Csv (Join-Path $Root 'metric-correlations.csv') -NoTypeInformation -Encoding UTF8
  $dateDirs=@(Get-ChildItem $Logs -Directory | Where-Object Name -Match '^\d{4}-\d{2}-\d{2}$' | Sort-Object Name)
  $events=@($dateDirs|ForEach-Object {Import-Csv (Join-Path $_.FullName 'system-events.csv') -ErrorAction SilentlyContinue})
  $gpuCount=@($gpuRows|Where-Object gpu).Count
  $cpuTotal=@($cpuRows|Where-Object logical_processor -eq '_Total')
  $sb=New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('# NEXO DUAL GPU — Resumo da campanha de monitoramento')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine("Encerramento: $Reason. Início: $($Start.ToString('o')); fim: $((Get-Date).ToString('o')).")
  [void]$sb.AppendLine("Amostras GPU: $gpuCount; amostras CPU total: $($cpuTotal.Count); eventos Windows elegíveis: $(@($events|Where-Object type -eq 'windows_event').Count).")
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Dispositivo | Métrica | n | Média | Mediana | Mín | Máx | DP | CV% | Oscilação (heurística) | p95 | p99 |')
  [void]$sb.AppendLine('|---|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|')
  foreach($x in $metricStats){[void]$sb.AppendLine("| $($x.device) | $($x.metric) | $($x.samples) | $($x.mean) | $($x.median) | $($x.min) | $($x.max) | $($x.stddev) | $($x.cv_percent) | $($x.variability_flag) | $($x.p95) | $($x.p99) |")}
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('A variabilidade é sinalizada por CV >= 10% como heurística, sem implicar falha. As correlações Pearson estão em `metric-correlations.csv`; são descritivas, não comprovam causalidade. Ausência de valores significa sensor/leitura indisponível, não zero.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('Eventos, processos e telemetria bruta estão em `logs\AAAA-MM-DD\`. A coleta não executou benchmarks, jogos nem tarefas de estresse. Lacunas podem ocorrer durante suspensão, indisponibilidade de `nvidia-smi` ou desligamento do host.')
  [IO.File]::WriteAllText((Join-Path $Root 'monitoring-summary.md'),$sb.ToString(),[Text.UTF8Encoding]::new($false))
  $report=@"
# NEXO DUAL GPU — Fase 4: relatório da campanha

## Estado da coleta

- Encerrada: $((Get-Date).ToString('o'))
- Motivo: $Reason
- Diretório de dados diários: `logs\AAAA-MM-DD\`
- Resumo estatístico: `monitoring-summary.md`

## Auditoria inicial

- Windows 11 Pro 10.0.26200, i7-3770K (4 núcleos / 8 lógicos), 32 GiB visíveis, placa SMBIOS Gigabyte Z77X-UP5 TH-CF.
- GTX 970 e GTX 750 Ti detectadas como `OK`, ambas driver 32.0.15.8278 e 4096 MiB reportados pelo NVIDIA-SMI. Nesta amostra inicial: GTX 970 38 °C, GTX 750 Ti 30 °C; uso GPU 1% e 3%; VRAM 415 MiB e 101 MiB; clocks gráficos 135 MHz; memória 324 / 405 MHz; fan 0% / 33%; potência 15,98 / 0,80 W.
- PCIe inicial: ambas Gen3 x8, máxima Gen3 x16 informada pelo NVIDIA-SMI. São leituras do estado atual e não confirmação de capacidade elétrica do slot.
- CPU em 3.901 MHz no snapshot inicial e 11% de carga CIM. RAM em uso aproximado 6,4 GiB. Unidade E: 239.720.247.296 bytes livres de 499.485.851.648.
- Sensores WMI de temperatura CPU encontrados como `Unknown` ou sem leitura. Temperatura CPU indisponível; o monitor não executa cargas ativas.
- `Get-AppxPackage -AllUsers` foi negado por permissões. No perfil atual não apareceu pacote `Forza`, e não havia processo Forza/instalador na consulta. O estado da fila de download/instalação não pôde ser confirmado; a campanha não toca nesse processo.
- Consultas de eventos System das quatro horas anteriores não retornaram eventos filtrados de Display/nvlddmkm/WHEA/Disk/Kernel-PnP. Isso não prova ausência de eventos em outros logs ou períodos.

## Campanha e limites

O monitor consulta apenas telemetria de sistema e driver a cada 30 segundos, com arquivos separados por dia. A duração máxima configurada é cinco dias. Não altera BIOS, drivers, registro, energia ou proteções, e não reinicia nem desliga o computador. Para parar manualmente, crie o arquivo `STOP` nesta pasta; o monitor termina a próxima amostra e gera o resumo. A campanha também termina ao alcançar cinco dias.

Consulte `monitoring-summary.md` para estatísticas disponíveis e `metric-correlations.csv` para correlações exploratórias. Correlação não implica causalidade. Se o computador suspender, desligar ou perder o processo, haverá lacuna; nenhuma configuração de energia será alterada para evitar isso.
"@
  [IO.File]::WriteAllText((Join-Path $Root 'phase4-report.md'),$report,[Text.UTF8Encoding]::new($false))
}
Set-Content -LiteralPath $PidFile -Value $PID -Encoding ASCII
@"
# Auditoria inicial — $(Get-Date -Format o)

- Host: $env:COMPUTERNAME; Windows: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)
- Monitor passivo: intervalo $IntervalSeconds s; limite máximo $([Math]::Min(5,[Math]::Max(1,$MaxDays))) dias.
- Parada manual: criar o arquivo `STOP` nesta pasta. Não usar Stop-Process se quiser relatório final.
- Temperatura CPU: indisponível por sensor confiável detectado. Nenhuma tarefa ativa será executada.
- Forza Horizon 4: estado da fila não confirmado (consulta global sem permissão; ausência no perfil e nos processos observados).
- Dados rotacionados diariamente em `logs\AAAA-MM-DD\`.
"@ | Set-Content -LiteralPath (Join-Path $Root 'phase4-report.md') -Encoding UTF8
try {
  while ((Get-Date) -lt $End -and !(Test-Path -LiteralPath $StopFile)) {
    $now=Get-Date; $day=$now.ToString('yyyy-MM-dd')
    $DayDir=Join-Path $Logs $day
    if (!(Test-Path -LiteralPath $DayDir)) { New-Item -ItemType Directory -Path $DayDir | Out-Null; Get-DayFiles $DayDir }
    elseif (!$DayDir) { Get-DayFiles $DayDir }
    $stamp=$now.ToString('o')
    Get-GpuSamples $stamp
    foreach($g in @($script:LastGpuRows)) { if ((Num $g.temperature) -ge 75) { Add-SystemRow (Join-Path $DayDir 'system-events.csv') ([pscustomobject]@{timestamp=$stamp;type='thermal_threshold';source=$g.name;event_id='';level='Warning';message='GPU atingiu 75 C; monitor não executa tarefas ativas'}) } }
    Get-CpuSample $stamp
    Get-SystemSample $stamp
    Get-GpuProcessSample $stamp
    $remaining=$IntervalSeconds - ((Get-Date)-$now).TotalSeconds
    if ($remaining -gt 0) { Start-Sleep -Seconds ([Math]::Ceiling($remaining)) }
  }
  $reason=if(Test-Path -LiteralPath $StopFile){'parada manual pelo arquivo STOP'}else{'limite máximo de cinco dias'}
  Write-FinalReports $reason
}
catch {
  Add-CsvRow (Join-Path $Logs 'monitor-errors.csv') ([pscustomobject]@{timestamp=(Get-Date).ToString('o');error=$_.Exception.Message;script_line=$_.InvocationInfo.ScriptLineNumber})
  Write-FinalReports 'erro do monitor (ver logs/monitor-errors.csv)'
}
finally { Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue }


