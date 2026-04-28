@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-native-gameclient.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Native GameClient host failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
