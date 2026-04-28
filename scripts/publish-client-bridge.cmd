@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\build\publish-client-bridge.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Publish failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
