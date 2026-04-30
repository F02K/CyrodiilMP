@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-ue4ss-runtime.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo UE4SS runtime install failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
