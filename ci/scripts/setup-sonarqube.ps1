# setup-sonarqube.ps1 - Автоматическая настройка SonarQube
param(
    [string]$SonarUrl = "http://localhost:9000",
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "admin",
    [string]$NewPassword = "admin123",
    [string]$ProjectKey = "ut103",
    [string]$ProjectName = "UT 10.3"
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Автоматическая настройка SonarQube ===" -ForegroundColor Cyan

# Функция для API запросов
function Invoke-SonarApi {
    param($Endpoint, $Method = "POST", $Body = $null)
    
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AdminUser}:${AdminPassword}"))
    $headers = @{
        Authorization = "Basic $auth"
    }
    
    try {
        if ($Body) {
            return Invoke-RestMethod -Uri "${SonarUrl}${Endpoint}" -Method $Method -Headers $headers -Body $Body -UseBasicParsing
        } else {
            return Invoke-RestMethod -Uri "${SonarUrl}${Endpoint}" -Method $Method -Headers $headers -UseBasicParsing
        }
    } catch {
        return $null
    }
}

# 1. Проверка готовности
Write-Host "`n1. Проверка готовности SonarQube..." -ForegroundColor Yellow
$maxAttempts = 20
$attempt = 0

while ($attempt -lt $maxAttempts) {
    try {
        $status = Invoke-WebRequest -Uri "$SonarUrl/api/system/status" -UseBasicParsing -TimeoutSec 3
        $statusObj = ($status.Content | ConvertFrom-Json)
        if ($statusObj.status -eq "UP") {
            Write-Host "OK SonarQube готов" -ForegroundColor Green
            break
        }
    } catch {}
    
    $attempt++
    Write-Host "  Ожидание... попытка $attempt/$maxAttempts" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

if ($attempt -eq $maxAttempts) {
    Write-Host "ОШИБКА: SonarQube не готов" -ForegroundColor Red
    exit 1
}

# 2. Смена пароля (если требуется)
Write-Host "`n2. Проверка необходимости смены пароля..." -ForegroundColor Yellow
$result = Invoke-SonarApi -Endpoint "/api/users/change_password" -Body @{
    login = $AdminUser
    previousPassword = $AdminPassword
    password = $NewPassword
}

if ($result) {
    Write-Host "OK Пароль изменен на: $NewPassword" -ForegroundColor Green
    $AdminPassword = $NewPassword
} else {
    Write-Host "  Пароль уже изменен или не требуется" -ForegroundColor Gray
}

# 3. Создание проекта
Write-Host "`n3. Создание проекта $ProjectKey..." -ForegroundColor Yellow
$result = Invoke-SonarApi -Endpoint "/api/projects/create" -Body @{
    project = $ProjectKey
    name = $ProjectName
}

if ($result) {
    Write-Host "OK Проект создан: $ProjectKey" -ForegroundColor Green
} else {
    Write-Host "  Проект уже существует или ошибка создания" -ForegroundColor Yellow
}

# 4. Генерация токена
Write-Host "`n4. Генерация токена доступа..." -ForegroundColor Yellow
$tokenName = "ci-token-$(Get-Date -Format 'yyyyMMdd')"
$result = Invoke-SonarApi -Endpoint "/api/user_tokens/generate" -Body @{
    name = $tokenName
}

if ($result -and $result.token) {
    $token = $result.token
    Write-Host "OK Токен создан: $tokenName" -ForegroundColor Green
    Write-Host "   Токен: $token" -ForegroundColor Cyan
    
    # Сохранение токена
    $config = @{
        url = $SonarUrl
        projectKey = $ProjectKey
        projectName = $ProjectName
        token = $token
        tokenName = $tokenName
        generatedAt = (Get-Date).ToString('s')
    } | ConvertTo-Json -Depth 3
    
    $auditDir = "build/audit"
    if (-not (Test-Path $auditDir)) {
        New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
    }
    $config | Out-File -FilePath "$auditDir/sonarqube-setup.json" -Encoding UTF8 -Force
    Write-Host "   Конфигурация сохранена: $auditDir/sonarqube-setup.json" -ForegroundColor Gray
    
    # Обновление sonar-project.properties
    if (Test-Path "sonar-project.properties") {
        $content = Get-Content "sonar-project.properties" -Raw
        $content = $content -replace "sonar.login=.*", "sonar.login=$token"
        $content | Set-Content "sonar-project.properties" -NoNewline
        Write-Host "   sonar-project.properties обновлен" -ForegroundColor Gray
    }
} else {
    Write-Host "ОШИБКА: Не удалось создать токен" -ForegroundColor Red
}

# 5. Настройка Quality Gate
Write-Host "`n5. Настройка Quality Gate..." -ForegroundColor Yellow
$result = Invoke-SonarApi -Endpoint "/api/qualitygates/list" -Method GET

if ($result) {
    Write-Host "OK Quality Gates доступны" -ForegroundColor Green
} else {
    Write-Host "  Ошибка доступа к Quality Gates" -ForegroundColor Yellow
}

Write-Host "`n=== Настройка SonarQube завершена ===" -ForegroundColor Cyan
Write-Host "URL: $SonarUrl" -ForegroundColor Gray
Write-Host "Проект: $ProjectKey" -ForegroundColor Gray
Write-Host "Учетные данные: $AdminUser / $AdminPassword" -ForegroundColor Gray

