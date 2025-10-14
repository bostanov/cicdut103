@echo off
:: prep-os-admin.bat - Run prep-os.ps1 with Administrator privileges
cd /d "%~dp0\..\..\"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ci/scripts/prep-os.ps1' -Wait"
pause

