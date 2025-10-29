@echo off
echo ========================================
echo Installing GitSync Test Service
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

echo Stopping and removing existing service...
sc stop "GitSync-Service" 2>nul
sc delete "GitSync-Service" 2>nul

echo Waiting 3 seconds...
timeout /t 3 /nobreak >nul

echo Installing test service...
sc create "GitSync-Service" binPath= "powershell.exe -ExecutionPolicy Bypass -File C:\1C-CI-CD\ci\scripts\gitsync-service-test.ps1" DisplayName= "GitSync 1C Test Service" start= auto

if %errorLevel% == 0 (
    echo Test service installed successfully.
    
    echo Setting service description...
    sc description "GitSync-Service" "GitSync Test Service"
    
    echo Starting service...
    sc start "GitSync-Service"
    
    echo.
    echo Waiting 10 seconds for service to start...
    timeout /t 10 /nobreak >nul
    
    echo Checking service status...
    sc query "GitSync-Service"
    
    echo.
    echo Checking test log...
    if exist "C:\1C-CI-CD\logs\gitsync-service-test.log" (
        echo Log file created successfully:
        type "C:\1C-CI-CD\logs\gitsync-service-test.log"
    ) else (
        echo Log file not created
    )
    
    echo.
    echo Test service installation completed!
    
) else (
    echo Failed to install test service.
    pause
    exit /b 1
)

echo.
pause
