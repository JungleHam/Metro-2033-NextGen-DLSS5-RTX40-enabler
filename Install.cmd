@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
if errorlevel 1 (echo. & echo Installation failed. See the error above.)
echo.
pause
