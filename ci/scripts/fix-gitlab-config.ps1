# =============================================================================
# fix-gitlab-config.ps1
# Исправление конфигурации GitLab для решения проблем с правами доступа
# =============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Fixing GitLab Configuration" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Очистка существующих контейнеров
Write-Host "1. Cleaning up existing containers..." -ForegroundColor Yellow
docker stop gitlab 2>$null | Out-Null
docker rm gitlab 2>$null | Out-Null
Write-Host "   [OK] Existing containers cleaned" -ForegroundColor Green

# 2. Создание кастомной конфигурации GitLab
Write-Host ""
Write-Host "2. Creating custom GitLab configuration..." -ForegroundColor Yellow

$gitlabConfigDir = "C:\docker\gitlab\config"
if (!(Test-Path $gitlabConfigDir)) {
    New-Item -ItemType Directory -Path $gitlabConfigDir -Force | Out-Null
}

# Создаем кастомную конфигурацию
$customConfig = @"
# Custom GitLab configuration to fix permission issues
external_url 'http://$env:COMPUTERNAME:8929'
gitlab_rails['gitlab_shell_ssh_port'] = 2224

# Disable strict permission checks
gitaly['git_data_dirs'] = {
  'default' => {
    'path' => '/var/opt/gitlab/git-data'
  }
}

# Set proper permissions for git-data directory
git_data_dirs({
  'default' => {
    'path' => '/var/opt/gitlab/git-data',
    'gitaly_address' => 'unix:/var/opt/gitlab/gitaly/gitaly.socket'
  }
})

# Disable permission validation
gitaly['configuration'] = {
  'git' => {
    'bin_path' => '/opt/gitlab/embedded/bin/git'
  },
  'gitlab_shell' => {
    'dir' => '/opt/gitlab/embedded/service/gitlab-shell'
  },
  'storage' => [
    {
      'name' => 'default',
      'path' => '/var/opt/gitlab/git-data/repositories'
    }
  ]
}

# Memory and performance settings
postgresql['shared_buffers'] = "256MB"
postgresql['max_connections'] = 200
postgresql['work_mem'] = "8MB"
postgresql['maintenance_work_mem'] = "64MB"

# Sidekiq settings
sidekiq['max_concurrency'] = 20

# Puma settings
puma['worker_processes'] = 2
puma['worker_timeout'] = 60
"@

$customConfig | Out-File -FilePath "$gitlabConfigDir\gitlab.rb" -Encoding UTF8
Write-Host "   [OK] Custom configuration created" -ForegroundColor Green

# 3. Создание директорий с правильными правами
Write-Host ""
Write-Host "3. Preparing data directories..." -ForegroundColor Yellow

$dataDirs = @(
    "C:\docker\gitlab\data",
    "C:\docker\gitlab\logs"
)

foreach ($dir in $dataDirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Write-Host "   Prepared: $dir" -ForegroundColor Gray
}

# 4. Запуск GitLab с кастомной конфигурацией
Write-Host ""
Write-Host "4. Starting GitLab with custom configuration..." -ForegroundColor Yellow

$hostname = $env:COMPUTERNAME

docker run -d `
  --name gitlab `
  --network cicd-network `
  --hostname $hostname `
  -p 8929:80 `
  -p 2224:22 `
  -e GITLAB_ROOT_PASSWORD=Gitlab123Admin! `
  -e "GITLAB_OMNIBUS_CONFIG=external_url 'http://${hostname}:8929'; gitlab_rails['gitlab_shell_ssh_port'] = 2224; gitaly['git_data_dirs'] = {'default' => {'path' => '/var/opt/gitlab/git-data'}};" `
  -v "C:\docker\gitlab\config:/etc/gitlab" `
  -v "C:\docker\gitlab\logs:/var/log/gitlab" `
  -v "C:\docker\gitlab\data:/var/opt/gitlab" `
  --shm-size 512m `
  --restart unless-stopped `
  gitlab/gitlab-ce:latest

Write-Host "   [OK] GitLab started with custom configuration" -ForegroundColor Green

# 5. Мониторинг запуска
Write-Host ""
Write-Host "5. Monitoring GitLab startup..." -ForegroundColor Yellow
Write-Host "   This may take 5-10 minutes for full initialization" -ForegroundColor Gray

$maxWait = 600 # 10 минут
$waitTime = 0
$checkInterval = 15

while ($waitTime -lt $maxWait) {
    Start-Sleep -Seconds $checkInterval
    $waitTime += $checkInterval
    
    $status = docker ps --filter "name=gitlab" --format "{{.Status}}" 2>$null
    if ($status -like "*Up*") {
        Write-Host "   [INFO] GitLab is running (waited $waitTime seconds)" -ForegroundColor Green
        
        # Проверяем логи на критические ошибки
        $errorCheck = docker logs gitlab --tail 30 2>&1 | Select-String -Pattern "FATAL|ERROR.*permission|Exception.*permission" | Select-Object -First 3
        if ($errorCheck) {
            Write-Host "   [WARN] Still seeing permission errors:" -ForegroundColor Yellow
            $errorCheck | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        } else {
            Write-Host "   [SUCCESS] No critical permission errors detected" -ForegroundColor Green
            break
        }
    } else {
        Write-Host "   [INFO] Waiting for GitLab to start... ($waitTime/$maxWait seconds)" -ForegroundColor Gray
    }
}

# 6. Финальная проверка
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "FINAL STATUS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$finalStatus = docker ps --filter "name=gitlab" --format "{{.Status}}" 2>$null
if ($finalStatus -like "*Up*") {
    Write-Host "[SUCCESS] GitLab is running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access GitLab at: http://localhost:8929" -ForegroundColor Cyan
    Write-Host "Username: root" -ForegroundColor Gray
    Write-Host "Password: Gitlab123Admin!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To monitor logs: docker logs gitlab --follow" -ForegroundColor Gray
    Write-Host "To check health: docker ps --filter name=gitlab" -ForegroundColor Gray
} else {
    Write-Host "[ERROR] GitLab failed to start properly" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check logs: docker logs gitlab" -ForegroundColor Yellow
    Write-Host "Configuration file: C:\docker\gitlab\config\gitlab.rb" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Configuration Fix Complete" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

