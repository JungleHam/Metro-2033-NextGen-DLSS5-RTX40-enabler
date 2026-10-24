@echo off
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -Game LastLight -NrMode Ask
if errorlevel 1 echo Installation did not complete. Review the message above.
pause
