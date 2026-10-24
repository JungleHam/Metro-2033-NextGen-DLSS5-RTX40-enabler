@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EnableDirect.ps1" %*
pause
