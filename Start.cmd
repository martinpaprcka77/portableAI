@echo off
rem ===========================================================================
rem  Start.cmd - root shortcut: open the interactive launcher menu.
rem  Delegates to launcher\Start-PortableAI.cmd (which knows the pwsh fallback).
rem  Idempotent: running it repeatedly only opens the menu again.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "LAUNCHER=launcher\Start-PortableAI.cmd"
if not exist "%LAUNCHER%" goto fallback

call "%LAUNCHER%" %*
set "RC=%ERRORLEVEL%"
goto done

:fallback
echo [WARN] %LAUNCHER% not found - falling back to launcher\Menu.ps1
where pwsh.exe >nul 2>nul
if errorlevel 1 goto fallback_windows_powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "launcher\Menu.ps1" %*
set "RC=%ERRORLEVEL%"
goto done

:fallback_windows_powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "launcher\Menu.ps1" %*
set "RC=%ERRORLEVEL%"

:done
endlocal & exit /b %RC%
