@echo off
rem ===========================================================================
rem  Update.cmd - root shortcut: check (and optionally repair) the workspace.
rem  Calls scripts\SelfHeal.ps1. Default = report only, nothing is changed.
rem  Pass -Fix to actually repair:  Update.cmd -Fix
rem  Idempotent: -Fix only touches what deviates from the conventions.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "SCRIPT=scripts\SelfHeal.ps1"
if not exist "%SCRIPT%" (
    echo [FAIL] %SCRIPT% not found - workspace looks incomplete.
    endlocal & exit /b 1
)

where pwsh.exe >nul 2>nul
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
