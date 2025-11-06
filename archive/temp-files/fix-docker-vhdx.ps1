# Скрипт для исправления поврежденного Docker Desktop VHDX
# Запускается с правами администратора

Write-Host "=== Исправление Docker Desktop VHDX ===" -ForegroundColor Cyan

# Останавливаем все процессы Docker
Write-Host "`nОстановка Docker процессов..." -ForegroundColor Yellow
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "com.docker.*" -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object {$_.Name -like "*docker*"} | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5

# Останавливаем Hyper-V VM
Write-Host "Остановка DockerDesktopVM..." -ForegroundColor Yellow
Stop-VM -Name "DockerDesktopVM" -Force -ErrorAction SilentlyContinue -TurnOff

Start-Sleep -Seconds 3

# Удаляем поврежденные файлы vm-data
$vmDataPath = "C:\ProgramData\DockerDesktop\vm-data"
Write-Host "`nУдаление поврежденных файлов из $vmDataPath..." -ForegroundColor Yellow

if (Test-Path $vmDataPath) {
    try {
        # Пытаемся удалить весь каталог
        Remove-Item -Path $vmDataPath -Recurse -Force -ErrorAction Stop
        Write-Host "Успешно удалены файлы vm-data" -ForegroundColor Green
    }
    catch {
        Write-Host "Ошибка при удалении: $_" -ForegroundColor Red
        
        # Альтернативный подход - удаляем конкретные файлы
        Write-Host "Попытка удалить отдельные файлы..." -ForegroundColor Yellow
        
        $files = @(
            "$vmDataPath\DockerDesktop.vhdx"
            "$vmDataPath\settings.json"
        )
        
        foreach ($file in $files) {
            if (Test-Path $file) {
                try {
                    Remove-Item -Path $file -Force -ErrorAction Stop
                    Write-Host "  ✓ Удален: $file" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ Не удалось удалить: $file - $_" -ForegroundColor Red
                }
            }
        }
    }
}
else {
    Write-Host "Каталог vm-data не найден" -ForegroundColor Yellow
}

# Также удаляем кэш и временные файлы Docker
$pathsToClean = @(
    "$env:LOCALAPPDATA\Docker\wsl\data"
    "$env:APPDATA\Docker"
)

foreach ($path in $pathsToClean) {
    if (Test-Path $path) {
        Write-Host "Очистка: $path..." -ForegroundColor Yellow
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== Завершено ===" -ForegroundColor Cyan
Write-Host "Теперь можно запустить Docker Desktop" -ForegroundColor Green
Write-Host "Он создаст новый чистый VHDX файл" -ForegroundColor Green

# Спрашиваем пользователя
$response = Read-Host "`nЗапустить Docker Desktop сейчас? (Y/N)"
if ($response -eq "Y" -or $response -eq "y") {
    Write-Host "Запуск Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "Ожидайте 60-90 секунд для полного запуска..." -ForegroundColor Yellow
}

