@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0hex.ps1" %*
exit /b %ERRORLEVEL%
