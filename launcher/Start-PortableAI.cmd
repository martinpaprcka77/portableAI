@echo off
setlocal
cd /d "%~dp0"
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1"
if errorlevel 1 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1"
endlocal
