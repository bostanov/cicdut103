@echo off
echo CI/CD Services Manager - Enhanced Python Version
echo ===============================================
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
    echo Usage: %0 [install^|uninstall^|status^|start^|stop^|restart]
    echo.
    echo Examples:
    echo   %0 status    - Show service status
    echo   %0 install   - Install all services (requires admin)
    echo   %0 start     - Start all services
    echo   %0 stop      - Stop all services
    echo.
    echo Enhanced features:
    echo   - Direct Windows service management
    echo   - Better error handling
    echo   - No PowerShell dependency
    echo.
    pause
    exit /b 0
)

REM Run enhanced Python script
echo Running: python install-services-enhanced.py %1
echo.
python install-services-enhanced.py %1

echo.
echo Operation completed.
pause
