@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0analyze-runtime-dump.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Script failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
