# Установка задачи планировщика Windows для GitSync
# Запуск каждые 10 минут

$ErrorActionPreference = "Stop"

Write-Host "Установка задачи GitSync в планировщик Windows..." -ForegroundColor Green

# Параметры задачи
$TaskName = "GitSync-1C-Sync"
$TaskPath = "\CI-CD\"
$ScriptPath = "C:\1C-CI-CD\gitsync-run.ps1"

# Проверка существования скрипта
if (-not (Test-Path $ScriptPath)) {
    Write-Host "❌ Файл $ScriptPath не найден!" -ForegroundColor Red
    exit 1
}

# Удаление существующей задачи (если есть)
$existingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Удаление существующей задачи..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
}

# Создание триггера (каждые 10 минут)
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 10) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

# Создание действия
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Настройки задачи
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

# Создание задачи
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

# Регистрация задачи
Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath $TaskPath `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -Principal $principal `
    -Description "GitSync - синхронизация хранилища 1С с Git (каждые 10 минут)"

Write-Host "✅ Задача '$TaskName' успешно создана!" -ForegroundColor Green
Write-Host "Расписание: каждые 10 минут" -ForegroundColor Cyan
Write-Host "Скрипт: $ScriptPath" -ForegroundColor Cyan

# Проверка задачи
Write-Host "`nПроверка созданной задачи:" -ForegroundColor Yellow
Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Format-List

Write-Host "`nДля запуска вручную используйте:" -ForegroundColor Yellow
Write-Host "Start-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath'" -ForegroundColor Cyan

Write-Host "`nДля удаления задачи используйте:" -ForegroundColor Yellow
Write-Host "Unregister-ScheduledTask -TaskName '$TaskName' -TaskPath '$TaskPath' -Confirm:`$false" -ForegroundColor Cyan

