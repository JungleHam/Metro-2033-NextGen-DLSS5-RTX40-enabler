@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0DisableDirect.ps1" %*
pause
