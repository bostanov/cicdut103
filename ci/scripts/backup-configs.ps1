# =============================================================================
# backup-configs.ps1
# Резервное копирование конфигураций и данных CI/CD инфраструктуры
# =============================================================================

param(
    [string]$BackupPath = "C:\Backups\1C-CI-CD",
    [switch]$IncludeDockerVolumes,
    [switch]$Verbose
)

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Резервное копирование CI/CD конфигураций                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = "$BackupPath\$timestamp"

Write-Host "Создание резервной копии..." -ForegroundColor Yellow
Write-Host "Директория: $backupDir" -ForegroundColor Gray
Write-Host "Время: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Создание директории для backup
try {
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Write-Host "✓ Создана директория backup" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Ошибка создания директории: $_" -ForegroundColor Red
    exit 1
}

# Функция для копирования файлов
function Backup-Files {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Description
    )
    
    Write-Host "Копирование: $Description" -ForegroundColor Yellow
    
    try {
        if (Test-Path $Source) {
            $destPath = Join-Path $Destination (Split-Path $Source -Leaf)
            Copy-Item $Source $destPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ Скопировано: $Source" -ForegroundColor Green
            
            if ($Verbose) {
                $size = (Get-ChildItem $destPath -Recurse | Measure-Object -Property Length -Sum).Sum
                Write-Host "    Размер: $([Math]::Round($size / 1KB, 2)) KB" -ForegroundColor Gray
            }
            
            return $true
        } else {
            Write-Host "  ⚠ Пропущено (не найдено): $Source" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "  ✗ Ошибка: $_" -ForegroundColor Red
        return $false
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "1. Конфигурационные файлы" -ForegroundColor Cyan
Write-Host ""

$configBackups = 0

# CI/CD конфигурации
if (Backup-Files -Source "ci\config" -Destination $backupDir -Description "CI/CD конфигурации") {
    $configBackups++
}

# GitLab CI конфигурация
if (Backup-Files -Source ".gitlab-ci.yml" -Destination $backupDir -Description "GitLab CI pipeline") {
    $configBackups++
}

# SonarQube конфигурация
if (Backup-Files -Source "sonar-project.properties" -Destination $backupDir -Description "SonarQube проект") {
    $configBackups++
}

# Audit данные
if (Backup-Files -Source "build\audit" -Destination $backupDir -Description "Audit данные") {
    $configBackups++
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "2. Скрипты автоматизации" -ForegroundColor Cyan
Write-Host ""

if (Backup-Files -Source "ci\scripts" -Destination $backupDir -Description "Скрипты CI/CD") {
    $configBackups++
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "3. Документация" -ForegroundColor Cyan
Write-Host ""

if (Backup-Files -Source "docs" -Destination $backupDir -Description "Документация") {
    $configBackups++
}

if (Backup-Files -Source "README.md" -Destination $backupDir -Description "README") {
    $configBackups++
}

if (Backup-Files -Source "QUICKSTART.md" -Destination $backupDir -Description "QUICKSTART") {
    $configBackups++
}

# Docker volumes (опционально, может занять много места)
if ($IncludeDockerVolumes) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "4. Docker Volumes (это может занять время)" -ForegroundColor Cyan
    Write-Host ""
    
    $volumesDir = "$backupDir\docker-volumes"
    New-Item -ItemType Directory -Path $volumesDir -Force | Out-Null
    
    # PostgreSQL data
    Write-Host "Backup PostgreSQL данных..." -ForegroundColor Yellow
    try {
        docker run --rm -v postgres_data:/data -v ${volumesDir}:/backup alpine tar czf /backup/postgres_data.tar.gz /data 2>&1 | Out-Null
        Write-Host "  ✓ PostgreSQL данные сохранены" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Ошибка backup PostgreSQL: $_" -ForegroundColor Red
    }
    
    # GitLab backup
    Write-Host "Backup GitLab конфигурации..." -ForegroundColor Yellow
    try {
        docker exec gitlab gitlab-backup create 2>&1 | Out-Null
        Write-Host "  ✓ GitLab backup создан (внутри контейнера)" -ForegroundColor Green
        Write-Host "    Расположение: /var/opt/gitlab/backups/" -ForegroundColor Gray
    } catch {
        Write-Host "  ✗ Ошибка backup GitLab: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Резюме резервного копирования" -ForegroundColor Cyan
Write-Host ""

# Информация о backup
$backupInfo = @{
    timestamp = $timestamp
    date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    location = $backupDir
    files_backed_up = $configBackups
    docker_volumes = $IncludeDockerVolumes
}

$backupInfo | ConvertTo-Json | Out-File "$backupDir\backup-info.json" -Encoding utf8

# Размер backup
$totalSize = (Get-ChildItem $backupDir -Recurse | Measure-Object -Property Length -Sum).Sum
$sizeGB = [Math]::Round($totalSize / 1GB, 2)
$sizeMB = [Math]::Round($totalSize / 1MB, 2)

Write-Host "✓ Резервное копирование завершено!" -ForegroundColor Green
Write-Host ""
Write-Host "Статистика:" -ForegroundColor Yellow
Write-Host "  Файлов/папок: $configBackups" -ForegroundColor Gray
Write-Host "  Размер: $sizeMB MB" -ForegroundColor Gray
Write-Host "  Расположение: $backupDir" -ForegroundColor Gray
Write-Host ""
Write-Host "Для восстановления скопируйте файлы обратно в рабочую директорию." -ForegroundColor Yellow
Write-Host ""

# Список старых backup'ов
$oldBackups = Get-ChildItem $BackupPath -Directory | Sort-Object CreationTime -Descending | Select-Object -Skip 5

if ($oldBackups.Count -gt 0) {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "⚠ Найдено старых backup'ов: $($oldBackups.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Рекомендуется удалить старые backup'ы для экономии места:" -ForegroundColor Gray
    $oldBackups | ForEach-Object {
        Write-Host "  • $($_.Name) - $($_.CreationTime)" -ForegroundColor Gray
    }
    Write-Host ""
    $cleanup = Read-Host "Удалить старые backup'ы? (y/n)"
    if ($cleanup -eq 'y') {
        $oldBackups | Remove-Item -Recurse -Force
        Write-Host "✓ Старые backup'ы удалены" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Скрипт завершен успешно." -ForegroundColor Green

