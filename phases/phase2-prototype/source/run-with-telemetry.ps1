$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$log=Join-Path $root 'logs'
$stdout=Join-Path $log 'run.stdout.txt'
$stderr=Join-Path $log 'run.stderr.txt'
$telemetry=Join-Path $log 'telemetry.csv'
$summary=Join-Path $log 'execution-summary.txt'
Remove-Item -LiteralPath @($stdout,$stderr,$telemetry,$summary) -Force -ErrorAction SilentlyContinue
$fields='name,temperature.gpu,utilization.gpu,pcie.link.gen.current,pcie.link.width.current,memory.used'
"PRE-RUN $(Get-Date -Format o)" | Set-Content -LiteralPath $summary
nvidia-smi --query-gpu=$fields --format=csv | Add-Content -LiteralPath $summary
'Timestamp,Gpu0,Gpu1,CpuTotalPercent,SystemRamUsedMiB,ProcessWorkingSetMiB' | Set-Content -LiteralPath $telemetry
$proc=Start-Process -FilePath (Join-Path $root 'nexo_dual_gpu.exe') -ArgumentList @($root) -WorkingDirectory $root -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$sample=0
while(-not $proc.HasExited){
  $now=Get-Date -Format o
  $gpu=@(nvidia-smi --query-gpu=$fields --format=csv,noheader,nounits 2>$null)
  $os=Get-CimInstance Win32_OperatingSystem
  $cpu=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
  $p=Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
  $gpu0=if($gpu.Count -gt 0){$gpu[0]}else{'NA,NA,NA,NA,NA'}
  $gpu1=if($gpu.Count -gt 1){$gpu[1]}else{'NA,NA,NA,NA,NA'}
  $sysUsed=[math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1024,1)
  $ws=if($p){[math]::Round($p.WorkingSet64/1MB,1)}else{0}
  $cpuPct=if($cpu){$cpu.PercentProcessorTime}else{'NA'}
  $row=[pscustomobject]@{Timestamp=$now;Gpu0=$gpu0;Gpu1=$gpu1;CpuTotalPercent=$cpuPct;SystemRamUsedMiB=$sysUsed;ProcessWorkingSetMiB=$ws}
  $row | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Add-Content -LiteralPath $telemetry
  $sample++
  Start-Sleep -Milliseconds 450
  $proc.Refresh()
}
$proc.Refresh()
$proc.WaitForExit()
$proc.Refresh()
 $appPassed=(Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue) -contains "RESULT=PASS"; $exitText=[string]$proc.ExitCode; if([string]::IsNullOrWhiteSpace($exitText)){if($appPassed){"PROCESS_EXIT_CODE=NOT_CAPTURED; app printed RESULT=PASS and its success branch returns 0" | Add-Content -LiteralPath $summary}else{"PROCESS_EXIT_CODE=NOT_CAPTURED; no PASS marker" | Add-Content -LiteralPath $summary}}else{"EXIT_CODE=$exitText" | Add-Content -LiteralPath $summary}
"SAMPLES=$sample" | Add-Content -LiteralPath $summary
"POST-RUN $(Get-Date -Format o)" | Add-Content -LiteralPath $summary
nvidia-smi --query-gpu=$fields --format=csv | Add-Content -LiteralPath $summary
"CPU temperature: not provided by standard Windows counters/nvidia-smi on this host; not guessed." | Add-Content -LiteralPath $summary
Get-Content -LiteralPath $stdout
if(Test-Path $stderr){Get-Content -LiteralPath $stderr}
Get-Content -LiteralPath $summary
if(-not $appPassed){throw "Prototype did not print RESULT=PASS"}




