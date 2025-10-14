# setup-gitlab.ps1 - Автоматическая настройка GitLab
param(
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$RootPassword = "Gitlab123Admin!",
    [string]$ProjectName = "ut103",
    [string]$RunnerName = "1C-CI-CD-Runner"
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Автоматическая настройка GitLab ===" -ForegroundColor Cyan

# 1. Проверка готовности
Write-Host "`n1. Проверка готовности GitLab..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri $GitLabUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
            Write-Host "OK GitLab готов" -ForegroundColor Green
            break
        }
    } catch {}
    
    $attempt++
    Write-Host "  Ожидание... попытка $attempt/$maxAttempts" -ForegroundColor Gray
    Start-Sleep -Seconds 10
}

if ($attempt -eq $maxAttempts) {
    Write-Host "ОШИБКА: GitLab не готов" -ForegroundColor Red
    Write-Host "  Проверьте логи: docker logs gitlab" -ForegroundColor Yellow
    exit 1
}

# 2. Инструкции по настройке
Write-Host "`n2. Дальнейшая настройка..." -ForegroundColor Yellow
Write-Host "  ВНИМАНИЕ: Требуется ручная настройка через Web UI:" -ForegroundColor Yellow
Write-Host "  1. Откройте: $GitLabUrl" -ForegroundColor Gray
Write-Host "  2. Войдите как: root / $RootPassword" -ForegroundColor Gray
Write-Host "  3. Создайте проект: $ProjectName" -ForegroundColor Gray
Write-Host "  4. Settings -> CI/CD -> Runners -> Copy registration token" -ForegroundColor Gray

# 3. Подготовка команды регистрации Runner
Write-Host "`n3. Команда для регистрации GitLab Runner:" -ForegroundColor Yellow
$runnerCmd = @"
C:\Tools\gitlab-runner\gitlab-runner.exe register ``
  --url $GitLabUrl ``
  --registration-token YOUR_TOKEN ``
  --name "$RunnerName" ``
  --executor shell ``
  --tag-list "windows,1c"

# После регистрации установите как сервис:
C:\Tools\gitlab-runner\gitlab-runner.exe install --user "ci_1c" --password "YOUR_PASSWORD"
C:\Tools\gitlab-runner\gitlab-runner.exe start
"@

Write-Host $runnerCmd -ForegroundColor Cyan

# Сохранение конфигурации
$config = @{
    url = $GitLabUrl
    projectName = $ProjectName
    rootPassword = $RootPassword
    runnerSetupCommand = $runnerCmd
    setupInstructions = @(
        "Login to GitLab: $GitLabUrl (root/$RootPassword)",
        "Create project: $ProjectName",
        "Get registration token from: Settings -> CI/CD -> Runners",
        "Register runner using command above",
        "Push repository: git remote add origin $GitLabUrl/root/$ProjectName.git; git push -u origin master"
    )
    generatedAt = (Get-Date).ToString('s')
} | ConvertTo-Json -Depth 3

$auditDir = "build/audit"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}
$config | Out-File -FilePath "$auditDir/gitlab-setup.json" -Encoding UTF8 -Force

Write-Host "`n=== Настройка GitLab ===" -ForegroundColor Cyan
Write-Host "URL: $GitLabUrl" -ForegroundColor Gray
Write-Host "Root password: $RootPassword" -ForegroundColor Gray
Write-Host "Инструкции сохранены: $auditDir/gitlab-setup.json" -ForegroundColor Gray

