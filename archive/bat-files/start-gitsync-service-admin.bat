@echo off
echo Starting GitSync Service...

sc start "GitSync-Service"

echo.
echo Service start result:
sc query "GitSync-Service"

echo.
pause
