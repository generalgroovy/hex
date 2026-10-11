@echo off
setlocal
where.exe pwsh.exe >nul 2>nul
if errorlevel 1 (
    >&2 echo H.E.X. developer tasks require PowerShell 7.2 or later.
    >&2 echo Install PowerShell 7 and ensure pwsh.exe is on PATH, then retry this command.
    exit /b 1
)
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0hex.ps1" %*
exit /b %ERRORLEVEL%
