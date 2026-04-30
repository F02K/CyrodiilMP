@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-ue4ss.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo UE4SS build failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
