@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-nirnlab-uiplatformor.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo NirnLabUIPlatformOR build failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
