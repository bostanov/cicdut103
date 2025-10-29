@echo off
echo ========================================
echo Installing GitSync CMD Service
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

echo Installing CMD service...
sc create "GitSync-Service" binPath= "C:\1C-CI-CD\ci\scripts\gitsync-service.cmd" DisplayName= "GitSync 1C Synchronization Service" start= auto

if %errorLevel% == 0 (
    echo CMD service installed successfully.
    
    echo Setting service description...
    sc description "GitSync-Service" "Автоматическая синхронизация хранилища 1С с Git репозиторием"
    
    echo Configuring service recovery options...
    sc failure "GitSync-Service" reset= 86400 actions= restart/5000/restart/10000/restart/30000
    
    echo Starting service...
    sc start "GitSync-Service"
    
    echo.
    echo Waiting 10 seconds for service to start...
    timeout /t 10 /nobreak >nul
    
    echo Checking service status...
    sc query "GitSync-Service"
    
    echo.
    echo Checking service log...
    if exist "C:\1C-CI-CD\logs\gitsync-service.log" (
        echo Log file created successfully:
        type "C:\1C-CI-CD\logs\gitsync-service.log"
    ) else (
        echo Log file not created yet
    )
    
    echo.
    echo CMD service installation completed!
    
) else (
    echo Failed to install CMD service.
    pause
    exit /b 1
)

echo.
pause
