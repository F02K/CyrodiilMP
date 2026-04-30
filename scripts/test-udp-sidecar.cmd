@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-udp-sidecar.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo UDP sidecar smoke test failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
