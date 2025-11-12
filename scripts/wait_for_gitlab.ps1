# Скрипт ожидания готовности GitLab
$maxAttempts = 30
$attempt = 0
$sleepSeconds = 10

Write-Host "Ожидание готовности GitLab..." -ForegroundColor Cyan

while ($attempt -lt $maxAttempts) {
    $attempt++
    Write-Host "Попытка $attempt из $maxAttempts..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8929/users/sign_in" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ GitLab готов к работе!" -ForegroundColor Green
            exit 0
        }
    } catch {
        Write-Host "GitLab еще не готов: $($_.Exception.Message)" -ForegroundColor Gray
    }
    
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds $sleepSeconds
    }
}

Write-Host "❌ GitLab не запустился за отведенное время" -ForegroundColor Red
exit 1
