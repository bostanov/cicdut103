@echo off
REM Запуск fix-path-permanent.ps1 с правами администратора

echo ========================================
echo Добавление инструментов в PATH
echo ========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0ci\scripts\fix-path-permanent.ps1"

echo.
echo ========================================
echo Нажмите любую клавишу для выхода...
pause >nul

