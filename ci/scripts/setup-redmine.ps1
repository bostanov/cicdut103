# setup-redmine.ps1 - Автоматическая настройка Redmine
param(
    [string]$RedmineUrl = "http://localhost:3000",
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "admin",
    [string]$ProjectKey = "ut103",
    [string]$ProjectName = "UT 10.3"
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Автоматическая настройка Redmine ===" -ForegroundColor Cyan

# 1. Проверка готовности
Write-Host "`n1. Проверка готовности Redmine..." -ForegroundColor Yellow
$maxAttempts = 20
$attempt = 0

while ($attempt -lt $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri $RedmineUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "OK Redmine готов" -ForegroundColor Green
            break
        }
    } catch {}
    
    $attempt++
    Write-Host "  Ожидание... попытка $attempt/$maxAttempts" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

if ($attempt -eq $maxAttempts) {
    Write-Host "ОШИБКА: Redmine не готов" -ForegroundColor Red
    exit 1
}

# 2. Получение API ключа (требуется ручная активация в UI)
Write-Host "`n2. Настройка API..." -ForegroundColor Yellow
Write-Host "  ВНИМАНИЕ: REST API должен быть включен вручную:" -ForegroundColor Yellow
Write-Host "  1. Откройте: $RedmineUrl" -ForegroundColor Gray
Write-Host "  2. Войдите как: $AdminUser / $AdminPassword" -ForegroundColor Gray
Write-Host "  3. Administration -> Settings -> API -> Enable REST web service" -ForegroundColor Gray
Write-Host "  4. My account -> API access key -> Show" -ForegroundColor Gray

# Сохранение конфигурации
$config = @{
    url = $RedmineUrl
    projectKey = $ProjectKey
    projectName = $ProjectName
    adminUser = $AdminUser
    setupInstructions = @(
        "Enable REST API: Administration -> Settings -> API",
        "Get API key: My account -> API access key -> Show",
        "Create project: Projects -> New project",
        "Update ci/config/ci-settings.json with API key"
    )
    generatedAt = (Get-Date).ToString('s')
} | ConvertTo-Json -Depth 3

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}
$config | Out-File -FilePath "$auditDir/redmine-setup.json" -Encoding UTF8 -Force

Write-Host "`n=== Настройка Redmine ===" -ForegroundColor Cyan
Write-Host "URL: $RedmineUrl" -ForegroundColor Gray
Write-Host "Учетные данные: $AdminUser / $AdminPassword" -ForegroundColor Gray
Write-Host "Инструкции сохранены: $auditDir/redmine-setup.json" -ForegroundColor Gray

