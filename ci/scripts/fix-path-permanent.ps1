# =============================================================================
# fix-path-permanent.ps1
# Добавляет установленные инструменты в системный PATH постоянно
# Требует прав администратора
# =============================================================================

param()

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Добавление инструментов в системный PATH                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "✗ Ошибка: Требуются права администратора!" -ForegroundColor Red
    Write-Host "Запустите PowerShell от имени администратора и выполните:" -ForegroundColor Yellow
    Write-Host "  Set-Location '$PWD'" -ForegroundColor Gray
    Write-Host "  .\ci\scripts\fix-path-permanent.ps1" -ForegroundColor Gray
    exit 1
}

# Инструменты для добавления в PATH
$pathsToAdd = @(
    "C:\Program Files\1cv8\8.3.12.1714\bin",
    "C:\Tools\sonar-scanner\bin",
    "C:\Tools\gitlab-runner"
)

Write-Host "Добавление инструментов в системный PATH..." -ForegroundColor Yellow
Write-Host ""

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$modified = $false

foreach ($path in $pathsToAdd) {
    Write-Host "Проверка: $path" -ForegroundColor Gray
    
    # Проверка существования директории
    if (-not (Test-Path $path)) {
        Write-Host "  ⚠ Предупреждение: Путь не существует, пропускаем" -ForegroundColor Yellow
        continue
    }
    
    # Проверка наличия в PATH
    if ($currentPath -notlike "*$path*") {
        $currentPath = $currentPath.TrimEnd(';') + ";$path"
        Write-Host "  ✓ Добавлен в PATH" -ForegroundColor Green
        $modified = $true
    } else {
        Write-Host "  ○ Уже в PATH" -ForegroundColor Gray
    }
}

# Сохранение изменений
if ($modified) {
    try {
        [Environment]::SetEnvironmentVariable("Path", $currentPath, "Machine")
        Write-Host ""
        Write-Host "✓ PATH успешно обновлен!" -ForegroundColor Green
        Write-Host ""
        Write-Host "ВАЖНО: Требуется перезапуск PowerShell для применения изменений." -ForegroundColor Yellow
        Write-Host "После перезапуска выполните: .\ci\scripts\audit-tools.ps1" -ForegroundColor Gray
        
        # Обновление PATH для текущей сессии
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Write-Host ""
        Write-Host "PATH обновлен для текущей сессии PowerShell." -ForegroundColor Green
        
    } catch {
        Write-Host "✗ Ошибка при обновлении PATH: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "○ Все пути уже в PATH, изменения не требуются." -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Проверка доступности инструментов:" -ForegroundColor Cyan
Write-Host ""

# Проверка 1C Platform
try {
    $1cVersion = & "C:\Program Files\1cv8\8.3.12.1714\bin\1cv8.exe" /version 2>&1 | Select-Object -First 1
    if ($1cVersion) {
        Write-Host "✓ 1C Platform: $1cVersion" -ForegroundColor Green
    } else {
        Write-Host "✓ 1C Platform: 8.3.12.1714 (установлена)" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ 1C Platform: Не найдена" -ForegroundColor Red
}

# Проверка SonarScanner
try {
    $sonarVersion = & "C:\Tools\sonar-scanner\bin\sonar-scanner.bat" -v 2>&1 | Select-Object -First 1
    Write-Host "✓ SonarScanner: $sonarVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ SonarScanner: Не найден" -ForegroundColor Red
}

# Проверка GitLab Runner
try {
    $runnerVersion = & "C:\Tools\gitlab-runner\gitlab-runner.exe" --version 2>&1 | Select-Object -First 1
    Write-Host "✓ GitLab Runner: $runnerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ GitLab Runner: Не найден" -ForegroundColor Red
}

Write-Host ""
Write-Host "Скрипт завершен успешно." -ForegroundColor Green

