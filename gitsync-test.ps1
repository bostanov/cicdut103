# Тестирование GitSync перед установкой в планировщик
# Проверяет все компоненты и запускает синхронизацию

$ErrorActionPreference = "Stop"

Write-Host "=== Тестирование GitSync ===" -ForegroundColor Green

# 1. Проверка OneScript
Write-Host "`n1. Проверка OneScript..." -ForegroundColor Cyan
try {
    $oscriptVersion = & oscript -version 2>&1
    Write-Host "✅ OneScript: $oscriptVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ OneScript не найден!" -ForegroundColor Red
    exit 1
}

# 2. Проверка OPM
Write-Host "`n2. Проверка OPM..." -ForegroundColor Cyan
try {
    $opmVersion = & opm version 2>&1
    Write-Host "✅ OPM: $opmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ OPM не найден!" -ForegroundColor Red
    exit 1
}

# 3. Проверка GitSync
Write-Host "`n3. Проверка GitSync..." -ForegroundColor Cyan
try {
    $gitsyncHelp = & gitsync --version 2>&1
    Write-Host "✅ GitSync установлен" -ForegroundColor Green
} catch {
    Write-Host "❌ GitSync не найден!" -ForegroundColor Red
    exit 1
}

# 4. Проверка PreCommit1C
Write-Host "`n4. Проверка PreCommit1C..." -ForegroundColor Cyan
try {
    $precommitHelp = & precommit1c --help 2>&1
    Write-Host "✅ PreCommit1C установлен" -ForegroundColor Green
} catch {
    Write-Host "❌ PreCommit1C не найден!" -ForegroundColor Red
    exit 1
}

# 5. Проверка рабочей директории
Write-Host "`n5. Проверка рабочей директории..." -ForegroundColor Cyan
$workDir = "C:\1C-CI-CD\workspace"
if (Test-Path $workDir) {
    Write-Host "✅ Рабочая директория существует: $workDir" -ForegroundColor Green
    
    # Проверка файлов
    $files = @("gitsync.json", "AUTHORS", "VERSION")
    foreach ($file in $files) {
        $filePath = Join-Path $workDir $file
        if (Test-Path $filePath) {
            Write-Host "  ✅ $file" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $file не найден" -ForegroundColor Red
        }
    }
} else {
    Write-Host "❌ Рабочая директория не найдена: $workDir" -ForegroundColor Red
    exit 1
}

# 6. Проверка хранилища 1С
Write-Host "`n6. Проверка хранилища 1С..." -ForegroundColor Cyan
$storagePath = "C:\1crepository"
if (Test-Path $storagePath) {
    Write-Host "✅ Хранилище 1С существует: $storagePath" -ForegroundColor Green
    $storageFiles = Get-ChildItem $storagePath
    Write-Host "  Файлов в хранилище: $($storageFiles.Count)" -ForegroundColor Gray
} else {
    Write-Host "❌ Хранилище 1С не найдено: $storagePath" -ForegroundColor Red
    exit 1
}

# 7. Проверка платформы 1С
Write-Host "`n7. Проверка платформы 1С..." -ForegroundColor Cyan
$v8Path = "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8c.exe"
if (Test-Path $v8Path) {
    Write-Host "✅ Платформа 1С найдена: $v8Path" -ForegroundColor Green
} else {
    Write-Host "❌ Платформа 1С не найдена: $v8Path" -ForegroundColor Red
    exit 1
}

# 8. Тестовый запуск GitSync
Write-Host "`n8. Тестовый запуск GitSync..." -ForegroundColor Cyan
Write-Host "Нажмите Enter для запуска или Ctrl+C для отмены..." -ForegroundColor Yellow
$null = Read-Host

try {
    Set-Location $workDir
    Write-Host "Запуск: gitsync sync" -ForegroundColor Cyan
    Write-Host "Рабочая директория: $(Get-Location)" -ForegroundColor Gray
    Write-Host "---" -ForegroundColor Gray
    
    & gitsync sync
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "---" -ForegroundColor Gray
        Write-Host "✅ GitSync выполнен успешно!" -ForegroundColor Green
    } else {
        Write-Host "---" -ForegroundColor Gray
        Write-Host "❌ GitSync завершился с ошибкой (код: $LASTEXITCODE)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Ошибка при запуске GitSync: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Тестирование завершено ===" -ForegroundColor Green
Write-Host "`nЕсли все тесты прошли успешно, запустите:" -ForegroundColor Yellow
Write-Host ".\gitsync-install-task.ps1" -ForegroundColor Cyan
Write-Host "для установки автоматической синхронизации каждые 10 минут." -ForegroundColor Yellow

