@echo off
setlocal enabledelayedexpansion

REM GitSync Service CMD Script
set LOG_FILE=C:\1C-CI-CD\logs\gitsync-service-cmd.log
set SYNC_INTERVAL=600
set WORK_DIR=C:\1C-CI-CD

REM Ensure log directory exists
if not exist "C:\1C-CI-CD\logs" mkdir "C:\1C-CI-CD\logs"

REM Function to write log
:WriteLog
echo [%date% %time%] [INFO] %~1 >> "%LOG_FILE%"
goto :eof

call :WriteLog "GitSync Service CMD Script starting"

:MainLoop
call :WriteLog "Starting synchronization cycle"

REM Set environment variables
set REPO_PWD=123
set GITSYNC_STORAGE_PATH=file://C:/1crepository
set GITSYNC_WORKDIR=C:\1C-CI-CD
set GITSYNC_STORAGE_USER=gitsync
set GITSYNC_STORAGE_PASSWORD=123
set GITSYNC_V8VERSION=8.3.12.1714
set GITSYNC_V8_PATH=C:/Program Files/1cv8/8.3.12.1714/bin/1cv8.exe
set GITSYNC_TEMP=C:/Temp/1C-CI-CD/ib
set GITSYNC_RENAME_MODULE=true
set GITSYNC_RENAME_FORM=true
set GITSYNC_PROJECT_NAME=ut103-ci
set GITSYNC_WORKSPACE_LOCATION=C:/1C-CI-CD
set GITSYNC_LIMIT=5

REM Ensure temp directory exists
if not exist "C:\Temp\1C-CI-CD\ib" mkdir "C:\Temp\1C-CI-CD\ib"

REM Change to work directory
cd /d "%WORK_DIR%"

call :WriteLog "Executing GitSync sync"

REM Run GitSync
"C:\Program Files\OneScript\bin\gitsync.bat" sync >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% equ 0 (
    call :WriteLog "Synchronization completed successfully"
) else (
    call :WriteLog "Synchronization failed with exit code: %ERRORLEVEL%"
)

call :WriteLog "Waiting 10 minutes before next sync"
timeout /t %SYNC_INTERVAL% /nobreak >nul

goto MainLoop