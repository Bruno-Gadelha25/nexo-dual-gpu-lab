$root='E:\NEXO-DUAL-GPU\phase4-monitoring'
New-Item -ItemType File -Path (Join-Path $root 'STOP') -Force | Out-Null
Write-Output "Solicitada parada segura; resumo será finalizado pelo monitor."
