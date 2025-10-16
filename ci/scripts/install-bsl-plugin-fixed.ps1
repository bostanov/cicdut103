# =============================================================================
# install-bsl-plugin-fixed.ps1
# Установка BSL плагина для SonarQube
# =============================================================================

param(
    [string]$Version = "1.9.1",
    [string]$ExtensionsPath = "C:\docker\sonarqube\extensions\plugins"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Установка BSL плагина для SonarQube" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$pluginUrl = "https://github.com/1c-syntax/sonar-bsl-plugin-community/releases/download/v${Version}/sonar-bsl-plugin-community-${Version}.jar"
$pluginFile = "$ExtensionsPath\sonar-bsl-plugin-community-${Version}.jar"

Write-Host "Версия плагина: $Version" -ForegroundColor Gray
Write-Host "URL загрузки: $pluginUrl" -ForegroundColor Gray
Write-Host "Путь установки: $pluginFile" -ForegroundColor Gray
Write-Host ""

# Создание директории extensions, если не существует
if (-not (Test-Path $ExtensionsPath)) {
    Write-Host "Создание директории extensions..." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $ExtensionsPath -Force | Out-Null
        Write-Host "Директория создана: $ExtensionsPath" -ForegroundColor Green
    } catch {
        Write-Host "Ошибка создания директории: $_" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Проверка наличия плагина
if (Test-Path $pluginFile) {
    Write-Host "Плагин уже установлен: $pluginFile" -ForegroundColor Yellow
    Write-Host ""
    $overwrite = Read-Host "Перезаписать плагин? (y/n)"
    if ($overwrite -ne 'y') {
        Write-Host "Установка отменена." -ForegroundColor Gray
        exit 0
    }
}

# Загрузка плагина
Write-Host "Загрузка BSL плагина..." -ForegroundColor Yellow
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $pluginUrl -OutFile $pluginFile
    
    Write-Host "Плагин загружен: $pluginFile" -ForegroundColor Green
    
    # Проверка размера файла
    $fileInfo = Get-Item $pluginFile
    Write-Host "Размер файла: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    
} catch {
    Write-Host "Ошибка загрузки: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Попробуйте скачать плагин вручную:" -ForegroundColor Yellow
    Write-Host "  1. Откройте в браузере: $pluginUrl" -ForegroundColor Gray
    Write-Host "  2. Сохраните файл как: $pluginFile" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Следующие шаги:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Перезапустите SonarQube:" -ForegroundColor Yellow
Write-Host "   docker restart sonarqube" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Дождитесь готовности (2-3 минуты)" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Проверьте установку в UI:" -ForegroundColor Yellow
Write-Host "   http://localhost:9000/admin/marketplace" -ForegroundColor Gray
Write-Host "   (логин: admin, пароль: admin)" -ForegroundColor Gray
Write-Host ""

# Автоматический перезапуск
Write-Host "Перезапуск SonarQube..." -ForegroundColor Yellow
docker restart sonarqube
Write-Host "SonarQube перезапускается..." -ForegroundColor Green
Write-Host "Подождите 2-3 минуты для полной загрузки." -ForegroundColor Gray

Write-Host ""
Write-Host "Установка BSL плагина завершена!" -ForegroundColor Green
