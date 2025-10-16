# Master Service Installer - Installs all CI/CD services
param(
    [string]$Action = "install"
)

$Services = @(
    @{
        Name = "GitSync-1C-Service"
        DisplayName = "GitSync 1C Synchronization Service"
        InstallerScript = "ci\scripts\install-gitsync-service.ps1"
    },
    @{
        Name = "Precommit1C-Service"
        DisplayName = "Precommit1C External Files Monitor Service"
        InstallerScript = "ci\scripts\install-precommit1c-service.ps1"
    },
    @{
        Name = "GitLab-Runner-1C"
        DisplayName = "GitLab Runner 1C CI/CD Service"
        InstallerScript = "ci\scripts\install-runner-service.ps1"
    }
)

function Install-AllServices {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          INSTALLING ALL CI/CD SERVICES                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($Service in $Services) {
        Write-Host "Installing $($Service.DisplayName)..." -ForegroundColor Yellow
        try {
            & $Service.InstallerScript "install"
            Write-Host "✓ $($Service.DisplayName) installed" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to install $($Service.DisplayName): $_" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-Host "Starting all services..." -ForegroundColor Yellow
    foreach ($Service in $Services) {
        try {
            Start-Service -Name $Service.Name -ErrorAction SilentlyContinue
            Write-Host "✓ $($Service.DisplayName) started" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to start $($Service.DisplayName): $_" -ForegroundColor Red
        }
    }
}

function Uninstall-AllServices {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║          UNINSTALLING ALL CI/CD SERVICES               ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    foreach ($Service in $Services) {
        Write-Host "Uninstalling $($Service.DisplayName)..." -ForegroundColor Yellow
        try {
            & $Service.InstallerScript "uninstall"
            Write-Host "✓ $($Service.DisplayName) uninstalled" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to uninstall $($Service.DisplayName): $_" -ForegroundColor Red
        }
        Write-Host ""
    }
}

function Show-ServiceStatus {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          CI/CD SERVICES STATUS                         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($Service in $Services) {
        try {
            $ServiceStatus = Get-Service -Name $Service.Name -ErrorAction SilentlyContinue
            if ($ServiceStatus) {
                $StatusColor = switch($ServiceStatus.Status) {
                    "Running" { "Green" }
                    "Stopped" { "Red" }
                    "Starting" { "Yellow" }
                    "Stopping" { "Yellow" }
                    default { "Gray" }
                }
                Write-Host "$($Service.DisplayName): " -NoNewline
                Write-Host $ServiceStatus.Status -ForegroundColor $StatusColor
            } else {
                Write-Host "$($Service.DisplayName): " -NoNewline
                Write-Host "Not Installed" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "$($Service.DisplayName): " -NoNewline
            Write-Host "Error" -ForegroundColor Red
        }
    }
}

function Start-AllServices {
    Write-Host "Starting all CI/CD services..." -ForegroundColor Yellow
    foreach ($Service in $Services) {
        try {
            Start-Service -Name $Service.Name -ErrorAction SilentlyContinue
            Write-Host "✓ $($Service.DisplayName) started" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to start $($Service.DisplayName): $_" -ForegroundColor Red
        }
    }
}

function Stop-AllServices {
    Write-Host "Stopping all CI/CD services..." -ForegroundColor Yellow
    foreach ($Service in $Services) {
        try {
            Stop-Service -Name $Service.Name -Force -ErrorAction SilentlyContinue
            Write-Host "✓ $($Service.DisplayName) stopped" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to stop $($Service.DisplayName): $_" -ForegroundColor Red
        }
    }
}

# Main execution
switch ($Action.ToLower()) {
    "install" {
        Install-AllServices
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║          ALL SERVICES INSTALLED SUCCESSFULLY          ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    }
    "uninstall" {
        Uninstall-AllServices
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║          ALL SERVICES UNINSTALLED SUCCESSFULLY         ║" -ForegroundColor Red
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    }
    "status" {
        Show-ServiceStatus
    }
    "start" {
        Start-AllServices
    }
    "stop" {
        Stop-AllServices
    }
    "restart" {
        Stop-AllServices
        Start-Sleep -Seconds 5
        Start-AllServices
    }
    default {
        Write-Host "Usage: .\install-all-services.ps1 [install|uninstall|status|start|stop|restart]" -ForegroundColor Yellow
    }
}