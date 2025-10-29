@echo off
echo ========================================
echo Creating GitSync Service via PowerShell
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

echo Creating service via PowerShell...
powershell -Command "New-Service -Name 'GitSync-Service' -BinaryPathName 'C:\1C-CI-CD\ci\scripts\gitsync-service.cmd' -DisplayName 'GitSync 1C Synchronization Service' -Description 'Автоматическая синхронизация хранилища 1С с Git репозиторием' -StartupType Automatic"

if %errorLevel% == 0 (
    echo Service created successfully.
    
    echo Starting service...
    sc start "GitSync-Service"
    
    echo.
    echo Waiting 10 seconds for service to start...
    timeout /t 10 /nobreak >nul
    
    echo Checking service status...
    sc query "GitSync-Service"
    
    echo.
    echo Service installation completed!
    
) else (
    echo Failed to create service via PowerShell.
    pause
    exit /b 1
)

echo.
pause
