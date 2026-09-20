@echo off
setlocal
cd /d "%~dp0"
if not exist "flux2.exe" (
  echo FLUX 2 could not start because flux2.exe is missing.
  echo Extract the complete archive and try again.
  pause
  exit /b 2
)
"%~dp0flux2.exe" %*
set "FLUX2_EXIT_CODE=%ERRORLEVEL%"
if not "%FLUX2_EXIT_CODE%"=="0" (
  echo.
  echo FLUX 2 closed with error code %FLUX2_EXIT_CODE%.
  pause
)
exit /b %FLUX2_EXIT_CODE%
