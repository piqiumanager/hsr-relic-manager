@echo off
cd /d "%~dp0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0server.ps1"
exit /b
