@echo off
echo Starting GitSync Service...

sc start "GitSync-Service"

echo.
echo Service start result:
sc query "GitSync-Service"

echo.
echo Checking logs...
if exist "C:\1C-CI-CD\logs\gitsync-service.log" (
    echo Log file found:
    type "C:\1C-CI-CD\logs\gitsync-service.log"
) else (
    echo Log file not found
)

echo.
pause
