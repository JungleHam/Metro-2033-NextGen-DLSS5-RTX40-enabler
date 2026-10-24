@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Report.ps1" %*
pause
