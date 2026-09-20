@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0asset-inventory.ps1" %*
exit /b %ERRORLEVEL%
