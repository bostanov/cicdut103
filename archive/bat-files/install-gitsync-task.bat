@echo off
echo ========================================
echo Installing GitSync as Scheduled Task
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

echo Creating new GitSync scheduled task...
schtasks /create /tn "GitSync-Service" /tr "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command \"Set-Location 'C:\1C-CI-CD'; \$env:REPO_PWD='123'; \$env:GITSYNC_STORAGE_PATH='file://C:/1crepository'; \$env:GITSYNC_WORKDIR='.'; \$env:GITSYNC_STORAGE_USER='gitsync'; \$env:GITSYNC_STORAGE_PASSWORD=\$env:REPO_PWD; while(\$true){Write-Host 'Starting GitSync sync'; gitsync sync -R -F -P -G -l 5; Start-Sleep 600}\"" /sc minute /mo 10 /ru SYSTEM /f

if %errorLevel% == 0 (
    echo GitSync scheduled task created successfully.
    
    echo Starting task...
    schtasks /run /tn "GitSync-Service"
    
    echo.
    echo Waiting 10 seconds for task to start...
    timeout /t 10 /nobreak >nul
    
    echo Checking task status...
    schtasks /query /tn "GitSync-Service" /fo list
    
    echo.
    echo GitSync scheduled task installation completed!
    echo The task will run every 10 minutes automatically.
    
) else (
    echo Failed to create GitSync scheduled task.
    pause
    exit /b 1
)

echo.
pause
