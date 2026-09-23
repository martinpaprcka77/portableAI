@echo off
rem ===========================================================================
rem  Setup.cmd - root shortcut: install and configure the DeepSeek AI stack.
rem  Calls scripts\Setup-DeepSeekStack.ps1. Passes extra arguments through,
rem  e.g.  Setup.cmd -WhatIf  or  Setup.cmd -SkipInstall -SkipCheck
rem  Idempotent: already installed and configured components are skipped.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "SCRIPT=scripts\Setup-DeepSeekStack.ps1"
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
