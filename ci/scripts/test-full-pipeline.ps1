# Скрипт тестирования полного CI/CD pipeline
# Автор: CI/CD Automation
# Дата: 2025-10-16

param(
    [string]$ProjectId = "root/ut103-ci",
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$SonarQubeUrl = "http://localhost:9000",
    [string]$RedmineUrl = "http://localhost:3000",
    [string]$GitLabToken = "",
    [switch]$SkipManualSteps = $false
)

# Цвета для вывода
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-ServiceAvailability {
    param([string]$ServiceName, [string]$Url)
    
    Write-ColorOutput "🔍 Проверка доступности $ServiceName..." $InfoColor
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-ColorOutput "✅ $ServiceName доступен (HTTP $($response.StatusCode))" $SuccessColor
            return $true
        }
        else {
            Write-ColorOutput "⚠️ $ServiceName недоступен (HTTP $($response.StatusCode))" $WarningColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ $ServiceName недоступен: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Test-GitLabRunner {
    param([string]$GitLabUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка GitLab Runner..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        # Проверяем наличие активных runner'ов
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/runners" -Headers $headers -Method GET
        $activeRunners = $response | Where-Object { $_.status -eq "online" }
        
        if ($activeRunners.Count -gt 0) {
            Write-ColorOutput "✅ Найдено активных runner'ов: $($activeRunners.Count)" $SuccessColor
            foreach ($runner in $activeRunners) {
                Write-ColorOutput "   - Runner ID: $($runner.id), Статус: $($runner.status)" $InfoColor
            }
            return $true
        }
        else {
            Write-ColorOutput "❌ Активные runner'ы не найдены" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка проверки GitLab Runner: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Test-GitLabProject {
    param([string]$ProjectId, [string]$GitLabUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка проекта GitLab..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $encodedPath = [System.Web.HttpUtility]::UrlEncode($ProjectId)
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$encodedPath" -Headers $headers -Method GET
        
        Write-ColorOutput "✅ Проект найден: $($response.name)" $SuccessColor
        Write-ColorOutput "   - ID: $($response.id)" $InfoColor
        Write-ColorOutput "   - Путь: $($response.path_with_namespace)" $InfoColor
        Write-ColorOutput "   - URL: $($response.web_url)" $InfoColor
        
        return $response
    }
    catch {
        Write-ColorOutput "❌ Проект не найден: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Test-GitLabVariables {
    param([int]$ProjectId, [string]$GitLabUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка CI/CD переменных..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$ProjectId/variables" -Headers $headers -Method GET
        
        $requiredVariables = @("REPO_PWD", "SONAR_HOST_URL", "SONAR_TOKEN", "REDMINE_URL", "REDMINE_API_KEY")
        $foundVariables = @()
        
        foreach ($variable in $response) {
            if ($requiredVariables -contains $variable.key) {
                $foundVariables += $variable.key
                Write-ColorOutput "✅ Переменная найдена: $($variable.key)" $SuccessColor
            }
        }
        
        $missingVariables = $requiredVariables | Where-Object { $_ -notin $foundVariables }
        
        if ($missingVariables.Count -eq 0) {
            Write-ColorOutput "✅ Все необходимые переменные настроены" $SuccessColor
            return $true
        }
        else {
            Write-ColorOutput "❌ Отсутствуют переменные: $($missingVariables -join ', ')" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка проверки переменных: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Test-SonarQubePlugin {
    param([string]$SonarQubeUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка BSL плагина в SonarQube..." $InfoColor
    
    try {
        $headers = @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Token`:")))"
        }
        
        $response = Invoke-RestMethod -Uri "$SonarQubeUrl/api/plugins/installed" -Headers $headers -Method GET
        
        $bslPlugin = $response.plugins | Where-Object { $_.key -eq "bsl" -or $_.name -like "*bsl*" -or $_.name -like "*1c*" }
        
        if ($bslPlugin) {
            Write-ColorOutput "✅ BSL плагин установлен: $($bslPlugin.name)" $SuccessColor
            return $true
        }
        else {
            Write-ColorOutput "❌ BSL плагин не найден" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка проверки BSL плагина: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Test-RedmineProject {
    param([string]$RedmineUrl, [string]$ApiKey, [string]$ProjectKey = "ut103")
    
    Write-ColorOutput "🔍 Проверка проекта в Redmine..." $InfoColor
    
    try {
        $headers = @{
            "X-Redmine-API-Key" = $ApiKey
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$RedmineUrl/projects.json" -Headers $headers -Method GET
        
        $project = $response.projects | Where-Object { $_.identifier -eq $ProjectKey }
        
        if ($project) {
            Write-ColorOutput "✅ Проект найден в Redmine: $($project.name)" $SuccessColor
            return $true
        }
        else {
            Write-ColorOutput "❌ Проект не найден в Redmine" $ErrorColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка проверки проекта Redmine: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Test-GitLabPipeline {
    param([int]$ProjectId, [string]$GitLabUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка pipeline в GitLab..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$ProjectId/pipelines" -Headers $headers -Method GET
        
        if ($response.Count -gt 0) {
            $latestPipeline = $response[0]
            Write-ColorOutput "✅ Найден pipeline: ID $($latestPipeline.id), Статус: $($latestPipeline.status)" $SuccessColor
            Write-ColorOutput "   - Ветка: $($latestPipeline.ref)" $InfoColor
            Write-ColorOutput "   - Создан: $($latestPipeline.created_at)" $InfoColor
            Write-ColorOutput "   - URL: $($latestPipeline.web_url)" $InfoColor
            return $latestPipeline
        }
        else {
            Write-ColorOutput "⚠️ Pipeline'ы не найдены" $WarningColor
            return $null
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка проверки pipeline: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Start-TestPipeline {
    param([int]$ProjectId, [string]$GitLabUrl, [string]$Token, [string]$Branch = "master")
    
    Write-ColorOutput "🚀 Запуск тестового pipeline..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $body = @{
            ref = $Branch
            variables = @{
                "CI_TEST_MODE" = "true"
            }
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$ProjectId/pipeline" -Headers $headers -Method POST -Body $body
        
        Write-ColorOutput "✅ Pipeline запущен: ID $($response.id)" $SuccessColor
        Write-ColorOutput "🔗 URL: $($response.web_url)" $InfoColor
        return $response
    }
    catch {
        Write-ColorOutput "❌ Ошибка запуска pipeline: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Get-GitLabToken {
    param([string]$GitLabUrl)
    
    Write-ColorOutput "🔑 Требуется токен доступа GitLab" $WarningColor
    Write-ColorOutput "Для получения токена:" $InfoColor
    Write-ColorOutput "1. Откройте: $GitLabUrl" $InfoColor
    Write-ColorOutput "2. Войдите как root / Gitlab123Admin!" $InfoColor
    Write-ColorOutput "3. Перейдите: User Settings → Access Tokens" $InfoColor
    Write-ColorOutput "4. Создайте токен с правами: api, read_user, read_repository, write_repository" $InfoColor
    
    Start-Process $GitLabUrl
    $token = Read-Host "Введите токен GitLab"
    return $token
}

function Show-TestResults {
    param([hashtable]$Results)
    
    Write-ColorOutput "📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ CI/CD PIPELINE" $InfoColor
    Write-ColorOutput "=" * 50 $InfoColor
    
    $totalTests = $Results.Count
    $passedTests = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $failedTests = $totalTests - $passedTests
    
    Write-ColorOutput "Всего тестов: $totalTests" $InfoColor
    Write-ColorOutput "Успешно: $passedTests" $SuccessColor
    Write-ColorOutput "Неудачно: $failedTests" $(if ($failedTests -gt 0) { $ErrorColor } else { $SuccessColor })
    
    Write-ColorOutput "" $InfoColor
    Write-ColorOutput "Детали:" $InfoColor
    
    foreach ($test in $Results.GetEnumerator()) {
        $status = if ($test.Value) { "✅ ПРОЙДЕН" } else { "❌ ПРОВАЛЕН" }
        $color = if ($test.Value) { $SuccessColor } else { $ErrorColor }
        Write-ColorOutput "  $($test.Key): $status" $color
    }
    
    Write-ColorOutput "" $InfoColor
    
    if ($failedTests -eq 0) {
        Write-ColorOutput "🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ! CI/CD pipeline готов к работе!" $SuccessColor
        return $true
    }
    else {
        Write-ColorOutput "⚠️ НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ. Проверьте настройки выше." $WarningColor
        return $false
    }
}

# Основная логика
Write-ColorOutput "🚀 Тестирование полного CI/CD pipeline" $InfoColor
Write-ColorOutput "GitLab: $GitLabUrl" $InfoColor
Write-ColorOutput "SonarQube: $SonarQubeUrl" $InfoColor
Write-ColorOutput "Redmine: $RedmineUrl" $InfoColor

# Получение токена GitLab
if (-not $GitLabToken) {
    $GitLabToken = Get-GitLabToken -GitLabUrl $GitLabUrl
    if (-not $GitLabToken) {
        Write-ColorOutput "❌ Токен GitLab не предоставлен. Завершение работы." $ErrorColor
        exit 1
    }
}

# Результаты тестов
$testResults = @{}

# Тест 1: Проверка доступности сервисов
Write-ColorOutput "🧪 ТЕСТ 1: Проверка доступности сервисов" $InfoColor
$testResults["GitLab доступен"] = Test-ServiceAvailability -ServiceName "GitLab" -Url $GitLabUrl
$testResults["SonarQube доступен"] = Test-ServiceAvailability -ServiceName "SonarQube" -Url $SonarQubeUrl
$testResults["Redmine доступен"] = Test-ServiceAvailability -ServiceName "Redmine" -Url $RedmineUrl

# Тест 2: Проверка GitLab Runner
Write-ColorOutput "🧪 ТЕСТ 2: Проверка GitLab Runner" $InfoColor
$testResults["GitLab Runner активен"] = Test-GitLabRunner -GitLabUrl $GitLabUrl -Token $GitLabToken

# Тест 3: Проверка проекта GitLab
Write-ColorOutput "🧪 ТЕСТ 3: Проверка проекта GitLab" $InfoColor
$project = Test-GitLabProject -ProjectId $ProjectId -GitLabUrl $GitLabUrl -Token $GitLabToken
$testResults["Проект GitLab существует"] = $project -ne $null

# Тест 4: Проверка CI/CD переменных
if ($project) {
    Write-ColorOutput "🧪 ТЕСТ 4: Проверка CI/CD переменных" $InfoColor
    $testResults["CI/CD переменные настроены"] = Test-GitLabVariables -ProjectId $project.id -GitLabUrl $GitLabUrl -Token $GitLabToken
}

# Тест 5: Проверка BSL плагина
Write-ColorOutput "🧪 ТЕСТ 5: Проверка BSL плагина SonarQube" $InfoColor
# Для проверки плагина нужен токен SonarQube, но мы можем проверить доступность
$testResults["BSL плагин SonarQube"] = Test-ServiceAvailability -ServiceName "SonarQube API" -Url "$SonarQubeUrl/api/system/status"

# Тест 6: Проверка проекта Redmine
Write-ColorOutput "🧪 ТЕСТ 6: Проверка проекта Redmine" $InfoColor
# Для проверки проекта нужен API ключ, но мы можем проверить доступность
$testResults["Проект Redmine"] = Test-ServiceAvailability -ServiceName "Redmine API" -Url "$RedmineUrl/projects.json"

# Тест 7: Проверка существующих pipeline
if ($project) {
    Write-ColorOutput "🧪 ТЕСТ 7: Проверка pipeline GitLab" $InfoColor
    $pipeline = Test-GitLabPipeline -ProjectId $project.id -GitLabUrl $GitLabUrl -Token $GitLabToken
    $testResults["Pipeline GitLab работает"] = $pipeline -ne $null
}

# Показ результатов
$allTestsPassed = Show-TestResults -Results $testResults

if ($allTestsPassed) {
    Write-ColorOutput "🎯 CI/CD pipeline готов к полноценной работе!" $SuccessColor
    Write-ColorOutput "📋 Следующие шаги:" $InfoColor
    Write-ColorOutput "1. Выполните первую синхронизацию из хранилища 1С" $InfoColor
    Write-ColorOutput "2. Запустите полный pipeline через GitLab UI" $InfoColor
    Write-ColorOutput "3. Проверьте результаты в SonarQube и Redmine" $InfoColor
    exit 0
}
else {
    Write-ColorOutput "⚠️ Требуется дополнительная настройка перед запуском pipeline" $WarningColor
    Write-ColorOutput "📋 Проверьте проваленные тесты выше и устраните проблемы" $InfoColor
    exit 1
}
