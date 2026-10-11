@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fullbody_preview.ps1" %*
exit /b %errorlevel%
