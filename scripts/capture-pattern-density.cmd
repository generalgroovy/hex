@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture-pattern-density.ps1" %*
exit /b %ERRORLEVEL%
