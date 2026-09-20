@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture-visual-matrix.ps1" %*
exit /b %ERRORLEVEL%
