@echo off
rem ===========================================================================
rem  Diag.cmd - root shortcut: run the read-only diagnostic snapshot.
rem  Calls scripts\Get-AiStackInfo.ps1. Passes extra arguments through,
rem  e.g.  Diag.cmd -Json  or  Diag.cmd -NoBanner
rem  Idempotent: diagnostics never changes workspace state.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "SCRIPT=scripts\Get-AiStackInfo.ps1"
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
