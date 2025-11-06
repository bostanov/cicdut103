# Принудительное исправление Docker Desktop
# ТРЕБУЕТСЯ ЗАПУСК С ПРАВАМИ АДМИНИСТРАТОРА!

Write-Host "=== ПРИНУДИТЕЛЬНОЕ ВОССТАНОВЛЕНИЕ DOCKER DESKTOP ===" -ForegroundColor Red
Write-Host "Этот скрипт полностью удалит Docker VM и пересоздаст его" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Продолжить? (YES для подтверждения)"
if ($confirmation -ne "YES") {
    Write-Host "Отменено пользователем" -ForegroundColor Yellow
    exit
}

# Шаг 1: Убить все процессы Docker
Write-Host "`n[1/7] Остановка процессов Docker..." -ForegroundColor Cyan
$dockerProcesses = Get-Process | Where-Object {$_.Name -like "*docker*" -or $_.Name -like "*com.docker*"}
foreach ($proc in $dockerProcesses) {
    Write-Host "  Остановка: $($proc.Name) (PID: $($proc.Id))"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3

# Шаг 2: Остановить и удалить VM из Hyper-V
Write-Host "`n[2/7] Остановка и удаление Hyper-V VM..." -ForegroundColor Cyan
$vmName = "DockerDesktopVM"

# Проверяем существование VM
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    Write-Host "  VM найдена: $vmName"
    
    # Принудительная остановка
    if ($vm.State -ne "Off") {
        Write-Host "  Остановка VM..."
        Stop-VM -Name $vmName -TurnOff -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
    }
    
    # Удаление VM
    Write-Host "  Удаление VM из Hyper-V..."
    Remove-VM -Name $vmName -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ VM удалена" -ForegroundColor Green
}
else {
    Write-Host "  VM не найдена (это нормально)" -ForegroundColor Yellow
}

Start-Sleep -Seconds 3

# Шаг 3: Удалить виртуальные коммутаторы Docker
Write-Host "`n[3/7] Удаление виртуальных коммутаторов..." -ForegroundColor Cyan
$switches = Get-VMSwitch | Where-Object {$_.Name -like "*Docker*"}
foreach ($switch in $switches) {
    Write-Host "  Удаление: $($switch.Name)"
    Remove-VMSwitch -Name $switch.Name -Force -ErrorAction SilentlyContinue
}

# Шаг 4: Удалить все файлы Docker Desktop
Write-Host "`n[4/7] Удаление файлов Docker Desktop..." -ForegroundColor Cyan

$pathsToDelete = @(
    "C:\ProgramData\DockerDesktop\vm-data",
    "C:\ProgramData\DockerDesktop\pki",
    "$env:LOCALAPPDATA\Docker\wsl",
    "$env:APPDATA\Docker\settings"
)

foreach ($path in $pathsToDelete) {
    if (Test-Path $path) {
        Write-Host "  Удаление: $path"
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "    ✓ Успешно" -ForegroundColor Green
        }
        catch {
            Write-Host "    ✗ Ошибка: $_" -ForegroundColor Red
            
            # Попытка через cmd для упрямых файлов
            Write-Host "    Попытка через cmd..."
            $cmdPath = $path -replace "/", "\"
            cmd /c "rd /s /q `"$cmdPath`" 2>nul"
            
            if (!(Test-Path $path)) {
                Write-Host "    ✓ Удалено через cmd" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "  Пропуск: $path (не существует)" -ForegroundColor Gray
    }
}

# Шаг 5: Очистка реестра (опционально)
Write-Host "`n[5/7] Очистка ключей реестра..." -ForegroundColor Cyan
$regPaths = @(
    "HKCU:\Software\Docker Inc."
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        Write-Host "  Удаление: $regPath"
        Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Шаг 6: Проверка оставшихся процессов
Write-Host "`n[6/7] Финальная проверка процессов..." -ForegroundColor Cyan
$remainingProcs = Get-Process | Where-Object {$_.Name -like "*docker*"}
if ($remainingProcs) {
    Write-Host "  Найдены оставшиеся процессы:" -ForegroundColor Yellow
    $remainingProcs | Format-Table Name, Id, StartTime
}
else {
    Write-Host "  ✓ Все процессы Docker остановлены" -ForegroundColor Green
}

# Шаг 7: Запуск Docker Desktop
Write-Host "`n[7/7] Запуск Docker Desktop..." -ForegroundColor Cyan
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

if (Test-Path $dockerPath) {
    Start-Process $dockerPath
    Write-Host "  ✓ Docker Desktop запущен" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== ВАЖНО! ===" -ForegroundColor Yellow
    Write-Host "Подождите 90-120 секунд для полной инициализации" -ForegroundColor Yellow
    Write-Host "Docker создаст новый чистый VHDX файл" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Затем выполните:" -ForegroundColor Cyan
    Write-Host "  docker version" -ForegroundColor White
    Write-Host "  docker network create cicd-network" -ForegroundColor White
    Write-Host "  docker-compose -f docker-compose-external-services.yml up -d" -ForegroundColor White
}
else {
    Write-Host "  ✗ Docker Desktop не найден: $dockerPath" -ForegroundColor Red
    Write-Host "  Возможно, требуется переустановка Docker Desktop" -ForegroundColor Yellow
}

Write-Host "`n=== ЗАВЕРШЕНО ===" -ForegroundColor Green
Write-Host "Если проблема повторяется, потребуется:" -ForegroundColor Yellow
Write-Host "1. Перезагрузка компьютера" -ForegroundColor White
Write-Host "2. Или полная переустановка Docker Desktop" -ForegroundColor White

