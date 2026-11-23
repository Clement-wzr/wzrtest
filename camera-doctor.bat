@echo off
chcp 65001 >nul
title EVERGREEN camera doctor
setlocal
set "SCRIPT=%~dp0camera-doctor.ps1"

where powershell >nul 2>nul
if errorlevel 1 (
  echo [EVERGREEN] PowerShell not found.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "CODE=%ERRORLEVEL%"
echo.
echo [EVERGREEN] doctor finished with exit code %CODE%.
echo Add -Fix as an argument to reset the camera device (needs admin).
pause
exit /b %CODE%
