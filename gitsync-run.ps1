# GitSync - запуск синхронизации с хранилищем 1С
# Этот скрипт запускает GitSync на хост-машине Windows

$ErrorActionPreference = "Stop"

# Логирование
$LogFile = "C:\1C-CI-CD\logs\gitsync-$(Get-Date -Format 'yyyyMMdd').log"
New-Item -ItemType Directory -Force -Path "C:\1C-CI-CD\logs" | Out-Null

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "=== GitSync запуск ==="
Write-Log "Рабочая директория: C:\1C-CI-CD\workspace"
Write-Log "Хранилище 1С: C:\1crepository"

try {
    # Переход в рабочую директорию
    Set-Location "C:\1C-CI-CD\workspace"
    
    # Запуск GitSync
    Write-Log "Запуск: gitsync sync"
    
    $output = & gitsync sync 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Log "Вывод GitSync:"
    $output | ForEach-Object { Write-Log $_ }
    
    if ($exitCode -eq 0) {
        Write-Log "✅ GitSync выполнен успешно"
    } else {
        Write-Log "❌ GitSync завершился с ошибкой (код: $exitCode)"
        exit $exitCode
    }
    
} catch {
    Write-Log "❌ ОШИБКА: $_"
    Write-Log "Трассировка: $($_.ScriptStackTrace)"
    exit 1
}

Write-Log "=== GitSync завершен ==="

