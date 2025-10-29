@echo off
echo ========================================
echo Installing GitSync PowerShell Service
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

echo Installing PowerShell service...
sc create "GitSync-Service" binPath= "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command & {Set-Location 'C:\1C-CI-CD'; $env:REPO_PWD='123'; $env:GITSYNC_STORAGE_PATH='file://C:/1crepository'; $env:GITSYNC_WORKDIR='.'; $env:GITSYNC_STORAGE_USER='gitsync'; $env:GITSYNC_STORAGE_PASSWORD=$env:REPO_PWD; while($true){Write-Host 'Starting sync'; gitsync sync -R -F -P -G -l 5; Start-Sleep 600}}" DisplayName= "GitSync 1C Synchronization Service" start= auto

if %errorLevel% == 0 (
    echo PowerShell service installed successfully.
    
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
    echo PowerShell service installation completed!
    
) else (
    echo Failed to install PowerShell service.
    pause
    exit /b 1
)

echo.
pause
