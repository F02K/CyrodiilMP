@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-client-bridge.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Client bridge failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
