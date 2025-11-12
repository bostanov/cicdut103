# Ожидание готовности всех сервисов
# Автор: Бостанов Ф.А.

param(
    [int]$MaxWaitMinutes = 10,
    [int]$CheckIntervalSec = 30,
    [int]$RequiredPercentage = 75
)

$startTime = Get-Date
$maxWaitTime = $startTime.AddMinutes($MaxWaitMinutes)

Write-Host "=== ОЖИДАНИЕ ГОТОВНОСТИ СЕРВИСОВ ===" -ForegroundColor Cyan
Write-Host "Максимальное время ожидания: $MaxWaitMinutes минут" -ForegroundColor Yellow
Write-Host "Интервал проверки: $CheckIntervalSec секунд" -ForegroundColor Yellow
Write-Host "Требуемая готовность: $RequiredPercentage%`n" -ForegroundColor Yellow

$iteration = 0

while ((Get-Date) -lt $maxWaitTime) {
    $iteration++
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
    
    Write-Host "[$elapsed мин] Проверка #$iteration..." -ForegroundColor Cyan
    
    # Запуск проверки
    $checkResult = & ".\scripts\testing\check-services.ps1" -TimeoutSec 10
    
    # Проверка результатов
    $available = ($checkResult.Values | Where-Object { $_ -eq $true }).Count
    $total = $checkResult.Count
    $percentage = [math]::Round(($available / $total) * 100, 0)
    
    if ($percentage -ge $RequiredPercentage) {
        Write-Host "`n✅ СЕРВИСЫ ГОТОВЫ! ($percentage% доступно)" -ForegroundColor Green
        return $checkResult
    }
    
    Write-Host "Ожидание... (текущая готовность: $percentage%)" -ForegroundColor Yellow
    Write-Host "Следующая проверка через $CheckIntervalSec секунд`n" -ForegroundColor Gray
    
    Start-Sleep -Seconds $CheckIntervalSec
}

Write-Host "`n⚠️  ПРЕВЫШЕНО ВРЕМЯ ОЖИДАНИЯ" -ForegroundColor Red
Write-Host "Не все сервисы готовы за $MaxWaitMinutes минут" -ForegroundColor Yellow

return $checkResult

