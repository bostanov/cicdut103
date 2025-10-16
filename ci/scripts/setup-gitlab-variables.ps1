# Скрипт автоматической настройки CI/CD переменных в GitLab
# Автор: CI/CD Automation
# Дата: 2025-10-16

param(
    [string]$ProjectId = "root/ut103-ci",
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$GitLabToken = "",
    [string]$RepoPassword = "",
    [string]$SonarToken = "",
    [string]$RedmineApiKey = "",
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

function Test-GitLabConnection {
    param([string]$Url, [string]$Token)
    
    Write-ColorOutput "🔍 Проверка подключения к GitLab..." $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/api/v4/user" -Headers $headers -Method GET
        Write-ColorOutput "✅ Подключение к GitLab успешно. Пользователь: $($response.username)" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка подключения к GitLab: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Get-ProjectId {
    param([string]$ProjectPath, [string]$GitLabUrl, [string]$Token)
    
    Write-ColorOutput "🔍 Поиск проекта: $ProjectPath" $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $encodedPath = [System.Web.HttpUtility]::UrlEncode($ProjectPath)
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$encodedPath" -Headers $headers -Method GET
        Write-ColorOutput "✅ Проект найден. ID: $($response.id)" $SuccessColor
        return $response.id
    }
    catch {
        Write-ColorOutput "❌ Проект не найден: $($_.Exception.Message)" $ErrorColor
        return $null
    }
}

function Set-GitLabVariable {
    param(
        [int]$ProjectId,
        [string]$Key,
        [string]$Value,
        [string]$GitLabUrl,
        [string]$Token,
        [bool]$Masked = $true,
        [bool]$Protected = $false
    )
    
    Write-ColorOutput "🔧 Настройка переменной: $Key" $InfoColor
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $body = @{
            key = $Key
            value = $Value
            masked = $Masked
            protected = $Protected
        } | ConvertTo-Json
        
        $encodedProjectId = [System.Web.HttpUtility]::UrlEncode($ProjectId.ToString())
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$encodedProjectId/variables" -Headers $headers -Method POST -Body $body
        Write-ColorOutput "✅ Переменная $Key настроена успешно" $SuccessColor
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            # Переменная уже существует, обновляем
            Write-ColorOutput "⚠️ Переменная $Key уже существует, обновляем..." $WarningColor
            return Update-GitLabVariable -ProjectId $ProjectId -Key $Key -Value $Value -GitLabUrl $GitLabUrl -Token $Token -Masked $Masked -Protected $Protected
        }
        else {
            Write-ColorOutput "❌ Ошибка настройки переменной $Key : $($_.Exception.Message)" $ErrorColor
            return $false
        }
    }
}

function Update-GitLabVariable {
    param(
        [int]$ProjectId,
        [string]$Key,
        [string]$Value,
        [string]$GitLabUrl,
        [string]$Token,
        [bool]$Masked = $true,
        [bool]$Protected = $false
    )
    
    try {
        $headers = @{
            "PRIVATE-TOKEN" = $Token
            "Content-Type" = "application/json"
        }
        
        $body = @{
            value = $Value
            masked = $Masked
            protected = $Protected
        } | ConvertTo-Json
        
        $encodedProjectId = [System.Web.HttpUtility]::UrlEncode($ProjectId.ToString())
        $encodedKey = [System.Web.HttpUtility]::UrlEncode($Key)
        $response = Invoke-RestMethod -Uri "$GitLabUrl/api/v4/projects/$encodedProjectId/variables/$encodedKey" -Headers $headers -Method PUT -Body $body
        Write-ColorOutput "✅ Переменная $Key обновлена успешно" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка обновления переменной $Key : $($_.Exception.Message)" $ErrorColor
        return $false
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
    Write-ColorOutput "5. Скопируйте токен" $InfoColor
    
    if (-not $SkipManualSteps) {
        Start-Process $GitLabUrl
        $token = Read-Host "Введите токен GitLab"
        return $token
    }
    else {
        Write-ColorOutput "⚠️ Пропуск ручного ввода токена (SkipManualSteps = true)" $WarningColor
        return ""
    }
}

# Основная логика
Write-ColorOutput "🚀 Настройка CI/CD переменных GitLab" $InfoColor
Write-ColorOutput "Проект: $ProjectId" $InfoColor
Write-ColorOutput "GitLab URL: $GitLabUrl" $InfoColor

# Получение токена GitLab
if (-not $GitLabToken) {
    $GitLabToken = Get-GitLabToken -GitLabUrl $GitLabUrl
    if (-not $GitLabToken) {
        Write-ColorOutput "❌ Токен GitLab не предоставлен. Завершение работы." $ErrorColor
        exit 1
    }
}

# Проверка подключения
if (-not (Test-GitLabConnection -Url $GitLabUrl -Token $GitLabToken)) {
    Write-ColorOutput "❌ Не удалось подключиться к GitLab. Завершение работы." $ErrorColor
    exit 1
}

# Получение ID проекта
$projectId = Get-ProjectId -ProjectPath $ProjectId -GitLabUrl $GitLabUrl -Token $GitLabToken
if (-not $projectId) {
    Write-ColorOutput "❌ Проект не найден. Создайте проект в GitLab сначала." $ErrorColor
    exit 1
}

# Настройка переменных
Write-ColorOutput "🔧 Настройка CI/CD переменных..." $InfoColor

$variables = @{
    "SONAR_HOST_URL" = "http://localhost:9000"
    "REDMINE_URL" = "http://localhost:3000"
}

# Добавляем переменные с пользовательскими значениями
if ($RepoPassword) {
    $variables["REPO_PWD"] = $RepoPassword
}
if ($SonarToken) {
    $variables["SONAR_TOKEN"] = $SonarToken
}
if ($RedmineApiKey) {
    $variables["REDMINE_API_KEY"] = $RedmineApiKey
}

$successCount = 0
$totalCount = $variables.Count

foreach ($var in $variables.GetEnumerator()) {
    if (Set-GitLabVariable -ProjectId $projectId -Key $var.Key -Value $var.Value -GitLabUrl $GitLabUrl -Token $GitLabToken) {
        $successCount++
    }
}

Write-ColorOutput "📊 Результат настройки: $successCount/$totalCount переменных настроено успешно" $InfoColor

if ($successCount -eq $totalCount) {
    Write-ColorOutput "✅ Все CI/CD переменные настроены успешно!" $SuccessColor
    Write-ColorOutput "🎯 Проект готов к запуску CI/CD pipeline" $SuccessColor
    exit 0
}
else {
    Write-ColorOutput "⚠️ Некоторые переменные не удалось настроить. Проверьте логи выше." $WarningColor
    exit 1
}
