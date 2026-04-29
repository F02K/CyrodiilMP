@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0audit-repo-layout.ps1" %*
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" (
  echo.
  echo Repository layout audit failed with exit code %EXITCODE%.
)
echo.
pause
exit /b %EXITCODE%
