@echo off
echo CI/CD Services Manager - Simple Solution
echo ======================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python 3.6+ and add it to PATH
    pause
    exit /b 1
)

REM Check arguments
if "%1"=="" (
    echo Usage: %0 [status^|start^|stop^|restart^|install^|manual]
    echo.
    echo Commands:
    echo   status   - Show service status
    echo   start    - Start all services (if installed)
    echo   stop     - Stop all services (if installed)
    echo   restart  - Restart all services (if installed)
    echo   install  - Show installation instructions
    echo   manual   - Run services manually (no admin rights needed)
    echo.
    echo Recommended: %0 manual
    echo.
    pause
    exit /b 0
)

REM Run Python script
echo Running: python service-manager.py %1
echo.
python service-manager.py %1

echo.
echo Operation completed.
pause
