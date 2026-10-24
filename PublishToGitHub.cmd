@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PublishToGitHub.ps1" %*
pause
