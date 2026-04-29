@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-standalone-loader.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Standalone loader install failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
