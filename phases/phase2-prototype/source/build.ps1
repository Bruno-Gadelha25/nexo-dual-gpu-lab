param([string]$Configuration='Release')
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$vs='C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat'
$fxc='C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\fxc.exe'
$src=Join-Path $root 'nexo_dual_gpu.cpp'
$out=Join-Path $root 'nexo_dual_gpu.exe'
$hlsl=Join-Path $root 'compute.hlsl'
$cso=Join-Path $root 'compute.cso'
$log=Join-Path $root 'logs\build.log'
$cmd='call "'+$vs+'" -arch=x64 -host_arch=x64 >nul && "'+$fxc+'" /nologo /T cs_5_1 /E main /O3 /Ges /Fo "'+$cso+'" "'+$hlsl+'" && cl /nologo /EHsc /std:c++17 /O2 /W4 /DUNICODE /D_UNICODE "'+$src+'" /Fe:"'+$out+'" /link d3d12.lib dxgi.lib dxguid.lib d3dcompiler.lib ole32.lib psapi.lib'
cmd.exe /d /c $cmd 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
