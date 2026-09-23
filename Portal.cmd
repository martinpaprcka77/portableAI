@echo off
rem ===========================================================================
rem  Portal.cmd - root shortcut: open the landing page in the default browser.
rem  Uses launcher\Menu.ps1 -Action landing (the tested code path).
rem  Idempotent: opening the portal twice simply opens two browser tabs.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "TARGET=landing\index.html"
if not exist "%TARGET%" (
    echo [FAIL] %TARGET% not found - workspace looks incomplete.
    endlocal & exit /b 1
)

where pwsh.exe >nul 2>nul
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "launcher\Menu.ps1" -Action landing %*
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "launcher\Menu.ps1" -Action landing %*
)
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
