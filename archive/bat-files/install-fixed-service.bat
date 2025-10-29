@echo off
echo ========================================
echo Installing Fixed GitSync Service
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

echo Removing existing service...
sc delete "GitSync-Service" 2>nul

echo Installing fixed service...
sc create "GitSync-Service" binPath= "powershell.exe -ExecutionPolicy Bypass -File C:\1C-CI-CD\ci\scripts\gitsync-service-fixed.ps1" DisplayName= "GitSync 1C Synchronization Service" start= auto

if %errorLevel% == 0 (
    echo Service installed successfully.
    
    echo Setting service description...
    sc description "GitSync-Service" "Автоматическая синхронизация хранилища 1С с Git репозиторием"
    
    echo Configuring service recovery options...
    sc failure "GitSync-Service" reset= 86400 actions= restart/5000/restart/10000/restart/30000
    
    echo Starting service...
    sc start "GitSync-Service"
    
    echo.
    echo Waiting 20 seconds for service to start...
    timeout /t 20 /nobreak >nul
    
    echo Checking service status...
    sc query "GitSync-Service"
    
    echo.
    echo Checking service log...
    if exist "C:\1C-CI-CD\logs\gitsync-service-fixed.log" (
        echo Log file created successfully:
        type "C:\1C-CI-CD\logs\gitsync-service-fixed.log"
    ) else (
        echo Log file not created yet
    )
    
    echo.
    echo Fixed service installation completed!
    
) else (
    echo Failed to install fixed service.
    pause
    exit /b 1
)

echo.
pause
