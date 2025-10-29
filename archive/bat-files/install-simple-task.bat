@echo off
echo ========================================
echo Installing Simple GitSync Task
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
    echo.
) else (
    echo ERROR: This script must be run as Administrator!
    echo Right-click on this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Removing existing GitSync task...
schtasks /delete /tn "GitSync-Service" /f 2>nul

echo Creating simple GitSync task...
schtasks /create /tn "GitSync-Service" /tr "C:\1C-CI-CD\ci\scripts\gitsync-service.cmd" /sc minute /mo 10 /ru SYSTEM /f

if %errorLevel% == 0 (
    echo GitSync task created successfully.
    
    echo Starting task...
    schtasks /run /tn "GitSync-Service"
    
    echo.
    echo Waiting 10 seconds for task to start...
    timeout /t 10 /nobreak >nul
    
    echo Checking task status...
    schtasks /query /tn "GitSync-Service" /fo list
    
    echo.
    echo GitSync task installation completed!
    echo The task will run every 10 minutes automatically.
    
) else (
    echo Failed to create GitSync task.
    pause
    exit /b 1
)

echo.
pause
