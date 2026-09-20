@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0current-state.ps1" %*
exit /b %ERRORLEVEL%
