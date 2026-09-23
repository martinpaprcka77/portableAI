@echo off
setlocal
cd /d "%~dp0"
where pwsh.exe >nul 2>nul
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1" -Action setup
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "Menu.ps1" -Action setup
)
endlocal
