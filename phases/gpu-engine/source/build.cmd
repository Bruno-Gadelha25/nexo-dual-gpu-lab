@echo off
rem Compila o NEXO GPU ENGINE. Ajuste o caminho do VsDevCmd.bat se o Visual Studio estiver em outro lugar.
call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul 2>&1
cd /d %~dp0
cl /nologo /EHsc /std:c++17 /O2 /W4 /utf-8 /DUNICODE /D_UNICODE NexoGpuEngine.cpp /Fe:NexoGpuEngine.exe
