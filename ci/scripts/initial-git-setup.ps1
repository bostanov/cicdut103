# Скрипт первоначальной настройки Git репозитория
# Автор: CI/CD Automation
# Дата: 2025-10-16

param(
    [string]$RemoteUrl = "http://localhost:8929/root/ut103-ci.git",
    [string]$GitLabUrl = "http://localhost:8929",
    [string]$GitLabToken = "",
    [string]$BranchName = "master",
    [string]$CommitMessage = "Initial CI/CD setup",
    [switch]$Force = $false
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

function Test-GitInstalled {
    Write-ColorOutput "🔍 Проверка установки Git..." $InfoColor
    
    try {
        $gitVersion = git --version
        Write-ColorOutput "✅ Git установлен: $gitVersion" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Git не установлен или не найден в PATH" $ErrorColor
        return $false
    }
}

function Test-GitRepository {
    Write-ColorOutput "🔍 Проверка Git репозитория..." $InfoColor
    
    if (Test-Path ".git") {
        Write-ColorOutput "✅ Git репозиторий уже инициализирован" $SuccessColor
        return $true
    }
    else {
        Write-ColorOutput "❌ Git репозиторий не инициализирован" $ErrorColor
        return $false
    }
}

function Initialize-GitRepository {
    Write-ColorOutput "🔧 Инициализация Git репозитория..." $InfoColor
    
    try {
        git init
        Write-ColorOutput "✅ Git репозиторий инициализирован" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка инициализации Git репозитория: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Set-GitUser {
    param([string]$Name = "CI/CD Automation", [string]$Email = "cicd@automation.local")
    
    Write-ColorOutput "🔧 Настройка пользователя Git..." $InfoColor
    
    try {
        git config user.name $Name
        git config user.email $Email
        Write-ColorOutput "✅ Пользователь Git настроен: $Name <$Email>" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка настройки пользователя Git: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Set-GitRemote {
    param([string]$RemoteUrl, [string]$RemoteName = "origin")
    
    Write-ColorOutput "🔧 Настройка remote origin..." $InfoColor
    
    try {
        # Проверяем существующие remote
        $existingRemotes = git remote -v
        
        if ($existingRemotes -match $RemoteName) {
            Write-ColorOutput "⚠️ Remote '$RemoteName' уже существует" $WarningColor
            
            if ($Force) {
                Write-ColorOutput "🔄 Удаление существующего remote..." $InfoColor
                git remote remove $RemoteName
                Write-ColorOutput "✅ Существующий remote удален" $SuccessColor
            }
            else {
                Write-ColorOutput "ℹ️ Используем существующий remote" $InfoColor
                return $true
            }
        }
        
        # Добавляем новый remote
        git remote add $RemoteName $RemoteUrl
        Write-ColorOutput "✅ Remote '$RemoteName' настроен: $RemoteUrl" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка настройки remote: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Add-GitIgnore {
    Write-ColorOutput "🔧 Создание .gitignore..." $InfoColor
    
    $gitignoreContent = @"
# 1C Configuration
*.cf
*.cfe
*.epf
*.erf
*.dt
*.cfu
*.cfl

# Temporary files
*.tmp
*.temp
*.log
*.bak
*.backup

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# CI/CD specific
build/
dist/
*.zip
*.tar.gz

# Sensitive data
*.pwd
*.key
secrets/
.env

# External files (will be managed separately)
externals/
externals-src/

# Documentation builds
docs/_build/
"@
    
    try {
        $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding UTF8
        Write-ColorOutput "✅ .gitignore создан" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка создания .gitignore: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Add-FilesToGit {
    Write-ColorOutput "🔧 Добавление файлов в Git..." $InfoColor
    
    try {
        # Добавляем все файлы
        git add .
        
        # Проверяем статус
        $status = git status --porcelain
        if ($status) {
            Write-ColorOutput "✅ Файлы добавлены в индекс Git" $SuccessColor
            Write-ColorOutput "📋 Статус файлов:" $InfoColor
            git status --short
            return $true
        }
        else {
            Write-ColorOutput "⚠️ Нет изменений для коммита" $WarningColor
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Ошибка добавления файлов в Git: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function New-GitCommit {
    param([string]$Message)
    
    Write-ColorOutput "🔧 Создание коммита..." $InfoColor
    
    try {
        git commit -m $Message
        Write-ColorOutput "✅ Коммит создан: $Message" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка создания коммита: $($_.Exception.Message)" $ErrorColor
        return $false
    }
}

function Push-ToRemote {
    param([string]$RemoteName = "origin", [string]$BranchName = "master")
    
    Write-ColorOutput "🔧 Отправка в remote репозиторий..." $InfoColor
    
    try {
        # Устанавливаем upstream
        git push -u $RemoteName $BranchName
        Write-ColorOutput "✅ Код отправлен в remote репозиторий" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "❌ Ошибка отправки в remote: $($_.Exception.Message)" $ErrorColor
        
        # Проверяем, может быть нужно создать ветку в remote
        if ($_.Exception.Message -match "refs/heads/$BranchName") {
            Write-ColorOutput "🔧 Попытка создать ветку в remote..." $InfoColor
            try {
                git push -u $RemoteName HEAD:$BranchName
                Write-ColorOutput "✅ Ветка создана и код отправлен" $SuccessColor
                return $true
            }
            catch {
                Write-ColorOutput "❌ Ошибка создания ветки в remote: $($_.Exception.Message)" $ErrorColor
                return $false
            }
        }
        return $false
    }
}

function Test-RemoteConnection {
    param([string]$RemoteUrl, [string]$GitLabToken)
    
    Write-ColorOutput "🔍 Проверка подключения к remote репозиторию..." $InfoColor
    
    try {
        # Проверяем доступность GitLab
        $gitlabApiUrl = $RemoteUrl -replace "\.git$", "" -replace "git@", "http://" -replace ":", "/"
        $gitlabApiUrl = $gitlabApiUrl -replace "//git@", "//"
        
        if ($gitlabApiUrl -match "localhost:8929") {
            $gitlabApiUrl = "http://localhost:8929"
        }
        
        $headers = @{
            "PRIVATE-TOKEN" = $GitLabToken
        }
        
        $response = Invoke-RestMethod -Uri "$gitlabApiUrl/api/v4/user" -Headers $headers -Method GET
        Write-ColorOutput "✅ Подключение к GitLab успешно" $SuccessColor
        return $true
    }
    catch {
        Write-ColorOutput "⚠️ Не удалось проверить подключение к GitLab: $($_.Exception.Message)" $WarningColor
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
    
    Start-Process $GitLabUrl
    $token = Read-Host "Введите токен GitLab"
    return $token
}

# Основная логика
Write-ColorOutput "🚀 Первоначальная настройка Git репозитория" $InfoColor
Write-ColorOutput "Remote URL: $RemoteUrl" $InfoColor
Write-ColorOutput "Ветка: $BranchName" $InfoColor

# Проверка установки Git
if (-not (Test-GitInstalled)) {
    Write-ColorOutput "❌ Git не установлен. Завершение работы." $ErrorColor
    exit 1
}

# Получение токена GitLab для проверки подключения
if (-not $GitLabToken) {
    $GitLabToken = Get-GitLabToken -GitLabUrl $GitLabUrl
    if (-not $GitLabToken) {
        Write-ColorOutput "⚠️ Токен GitLab не предоставлен. Пропускаем проверку подключения." $WarningColor
    }
}

# Проверка подключения к remote
if ($GitLabToken) {
    Test-RemoteConnection -RemoteUrl $RemoteUrl -GitLabToken $GitLabToken
}

# Проверка/инициализация Git репозитория
if (-not (Test-GitRepository)) {
    if (-not (Initialize-GitRepository)) {
        Write-ColorOutput "❌ Не удалось инициализировать Git репозиторий. Завершение работы." $ErrorColor
        exit 1
    }
}

# Настройка пользователя Git
if (-not (Set-GitUser)) {
    Write-ColorOutput "❌ Не удалось настроить пользователя Git. Завершение работы." $ErrorColor
    exit 1
}

# Создание .gitignore
if (-not (Add-GitIgnore)) {
    Write-ColorOutput "❌ Не удалось создать .gitignore. Завершение работы." $ErrorColor
    exit 1
}

# Настройка remote
if (-not (Set-GitRemote -RemoteUrl $RemoteUrl)) {
    Write-ColorOutput "❌ Не удалось настроить remote. Завершение работы." $ErrorColor
    exit 1
}

# Добавление файлов в Git
if (-not (Add-FilesToGit)) {
    Write-ColorOutput "⚠️ Нет файлов для коммита" $WarningColor
    exit 0
}

# Создание коммита
if (-not (New-GitCommit -Message $CommitMessage)) {
    Write-ColorOutput "❌ Не удалось создать коммит. Завершение работы." $ErrorColor
    exit 1
}

# Отправка в remote
if (-not (Push-ToRemote -BranchName $BranchName)) {
    Write-ColorOutput "❌ Не удалось отправить код в remote. Проверьте настройки." $ErrorColor
    Write-ColorOutput "💡 Попробуйте выполнить команду вручную:" $InfoColor
    Write-ColorOutput "   git push -u origin $BranchName" $InfoColor
    exit 1
}

Write-ColorOutput "✅ Git репозиторий настроен успешно!" $SuccessColor
Write-ColorOutput "🎯 Код отправлен в GitLab: $RemoteUrl" $SuccessColor
Write-ColorOutput "🔗 Откройте проект в GitLab: $($RemoteUrl -replace '\.git$', '')" $InfoColor
