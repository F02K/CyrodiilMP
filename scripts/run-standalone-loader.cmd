@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-standalone-loader.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Standalone loader run failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
