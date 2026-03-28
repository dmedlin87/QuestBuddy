@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_quest-buddy.ps1" -PauseOnExit %*
set "exitCode=%ERRORLEVEL%"
exit /b %exitCode%