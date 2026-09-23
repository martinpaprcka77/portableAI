@echo off
rem ===========================================================================
rem  Test.cmd - root shortcut: run the workspace self-test.
rem  Calls scripts\Test-Workspace.ps1. Passes extra arguments through,
rem  e.g.  Test.cmd -Fix  or  Test.cmd -Json
rem  Idempotent: without -Fix the self-test only reports.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "SCRIPT=scripts\Test-Workspace.ps1"
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
