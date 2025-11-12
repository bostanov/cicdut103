# Диагностика проблем GitLab
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "GitLab Diagnostic Tool" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# 1. Проверка Docker
Write-Host "1. Проверка Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
    Write-Host "   ✅ Docker работает (версия: $dockerVersion)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Docker не работает!" -ForegroundColor Red
    Write-Host "   Запустите Docker Desktop и повторите попытку" -ForegroundColor Yellow
    exit 1
}

# 2. Проверка ресурсов Docker
Write-Host "`n2. Проверка ресурсов Docker..." -ForegroundColor Yellow
$dockerInfo = docker info --format '{{json .}}' | ConvertFrom-Json
$memoryGB = [math]::Round($dockerInfo.MemTotal / 1GB, 2)
$cpus = $dockerInfo.NCPU

Write-Host "   Memory: $memoryGB GB" -ForegroundColor White
Write-Host "   CPUs: $cpus" -ForegroundColor White

if ($memoryGB -lt 8) {
    Write-Host "   ⚠️  ВНИМАНИЕ: Недостаточно памяти!" -ForegroundColor Red
    Write-Host "   GitLab требует минимум 8GB RAM" -ForegroundColor Yellow
    Write-Host "   Текущее значение: $memoryGB GB" -ForegroundColor Yellow
    Write-Host "   Увеличьте память в Docker Desktop -> Settings -> Resources" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ Памяти достаточно" -ForegroundColor Green
}

if ($cpus -lt 4) {
    Write-Host "   ⚠️  Рекомендуется минимум 4 CPU" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ CPU достаточно" -ForegroundColor Green
}

# 3. Проверка контейнера GitLab
Write-Host "`n3. Проверка контейнера GitLab..." -ForegroundColor Yellow
$gitlabContainer = docker ps --filter "name=gitlab-cicd" --format "{{.Names}}" 2>&1

if ($gitlabContainer -eq "gitlab-cicd") {
    Write-Host "   ✅ Контейнер запущен" -ForegroundColor Green
    
    # Проверка статуса
    $status = docker ps --filter "name=gitlab-cicd" --format "{{.Status}}" 2>&1
    Write-Host "   Статус: $status" -ForegroundColor White
    
    # Проверка health
    if ($status -match "healthy") {
        Write-Host "   ✅ Контейнер healthy" -ForegroundColor Green
    } elseif ($status -match "unhealthy") {
        Write-Host "   ❌ Контейнер unhealthy" -ForegroundColor Red
    } else {
        Write-Host "   ⚠️  Контейнер starting..." -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Контейнер не запущен!" -ForegroundColor Red
    Write-Host "   Запустите контейнер: docker start gitlab-cicd" -ForegroundColor Yellow
    exit 1
}

# 4. Проверка веб-интерфейса
Write-Host "`n4. Проверка веб-интерфейса..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8929" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    Write-Host "   ✅ GitLab отвечает! HTTP $($response.StatusCode)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 502) {
        Write-Host "   ❌ 502 Bad Gateway - внутренние сервисы не запущены" -ForegroundColor Red
        Write-Host "   Возможные причины:" -ForegroundColor Yellow
        Write-Host "   - GitLab еще инициализируется (подождите 5-10 минут)" -ForegroundColor Yellow
        Write-Host "   - Недостаточно ресурсов (увеличьте RAM)" -ForegroundColor Yellow
        Write-Host "   - Проблемы с Redis или PostgreSQL" -ForegroundColor Yellow
    } else {
        Write-Host "   ❌ Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. Проверка логов
Write-Host "`n5. Последние логи GitLab..." -ForegroundColor Yellow
Write-Host "   (последние 10 строк)" -ForegroundColor Gray
docker logs gitlab-cicd --tail 10 2>&1 | ForEach-Object {
    Write-Host "   $_" -ForegroundColor Gray
}

# 6. Рекомендации
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host "РЕКОМЕНДАЦИИ" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

if ($memoryGB -lt 8) {
    Write-Host "`n🔧 КРИТИЧНО: Увеличьте память Docker" -ForegroundColor Red
    Write-Host "   1. Откройте Docker Desktop" -ForegroundColor White
    Write-Host "   2. Settings -> Resources" -ForegroundColor White
    Write-Host "   3. Memory: установите 8-12 GB" -ForegroundColor White
    Write-Host "   4. Apply & Restart" -ForegroundColor White
}

Write-Host "`n⏱️  Если GitLab только что запустился:" -ForegroundColor Yellow
Write-Host "   - Подождите 5-10 минут" -ForegroundColor White
Write-Host "   - Запустите этот скрипт снова" -ForegroundColor White

Write-Host "`n🔄 Если проблема сохраняется:" -ForegroundColor Yellow
Write-Host "   1. Перезапустите контейнер: docker restart gitlab-cicd" -ForegroundColor White
Write-Host "   2. Подождите 5 минут" -ForegroundColor White
Write-Host "   3. Проверьте снова: .\scripts\diagnose_gitlab.ps1" -ForegroundColor White

Write-Host "`n📖 Создание токена вручную:" -ForegroundColor Yellow
Write-Host "   См. подробную инструкцию в GITLAB_TOKEN_MANUAL.md" -ForegroundColor White

Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
