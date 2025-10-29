@echo off
echo ========================================
echo Reinstalling GitSync Service
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

echo Installing new GitSync service...
sc create "GitSync-Service" binPath= "powershell.exe -File C:\1C-CI-CD\ci\scripts\gitsync-service-script.ps1" DisplayName= "GitSync 1C Synchronization Service" start= auto

if %errorLevel% == 0 (
    echo Service installed successfully.
    
    echo Setting service description...
    sc description "GitSync-Service" "Автоматическая синхронизация хранилища 1С с Git репозиторием используя GitSync"
    
    echo Configuring service recovery options...
    sc failure "GitSync-Service" reset= 86400 actions= restart/5000/restart/10000/restart/30000
    
    echo Starting service...
    sc start "GitSync-Service"
    
    echo.
    echo Checking service status...
    sc query "GitSync-Service"
    
    echo.
    echo GitSync Service installation completed!
    
) else (
    echo Failed to install service.
    pause
    exit /b 1
)

echo.
pause
