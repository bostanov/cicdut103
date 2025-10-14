# prep-os.ps1 - OS preparation: ci_1c user, permissions, ports
param(
    [string]$Username = "ci_1c",
    [string]$Password = $null,
    [string[]]$Directories = @("C:\1crepository", "C:\1C-CI-CD", "C:\1C-CI-CD\build"),
    [int[]]$Ports = @(8929, 2224, 5432, 9000, 3000, 8081)
)

$ErrorActionPreference = 'Continue'

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "=== Stage 0: OS Prerequisites ===" -ForegroundColor Cyan
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator. Some operations may fail." -ForegroundColor Red
    Write-Host "         Please run PowerShell as Administrator for full setup." -ForegroundColor Yellow
}

# 1. Create ci_1c user
Write-Host "`n1. Checking user $Username..." -ForegroundColor Yellow
$user = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
if (-not $user) {
    if ($isAdmin) {
        Write-Host "User not found. Creating..." -ForegroundColor Yellow
        
        if (-not $Password) {
            # Generate random password
            Add-Type -AssemblyName System.Web
            $Password = [System.Web.Security.Membership]::GeneratePassword(16, 4)
        }
        
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        try {
            New-LocalUser -Name $Username -Password $SecurePassword -PasswordNeverExpires -Description "CI/CD 1C Service User" -ErrorAction Stop
            
            Write-Host "OK User $Username created" -ForegroundColor Green
            Write-Host "  Password saved to: build/audit/ci_1c_password.txt" -ForegroundColor Gray
            
            # Save password
            $auditDir = "build/audit"
            if (-not (Test-Path $auditDir)) {
                New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
            }
            $Password | Out-File -FilePath "$auditDir/ci_1c_password.txt" -Encoding UTF8 -Force
        } catch {
            Write-Host "FAILED: Could not create user: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "SKIP: User creation requires Administrator rights" -ForegroundColor Yellow
    }
} else {
    Write-Host "OK User $Username already exists" -ForegroundColor Green
}

# 2. Create directories and assign permissions
Write-Host "`n2. Checking directories and permissions..." -ForegroundColor Yellow
foreach ($dir in $Directories) {
    if (-not (Test-Path $dir)) {
        Write-Host "  Creating: $dir" -ForegroundColor Gray
        try {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "  FAILED: Could not create $dir : $_" -ForegroundColor Red
            continue
        }
    }
    
    if ($user -or $isAdmin) {
        Write-Host "  Setting permissions: $dir -> $Username (Modify)" -ForegroundColor Gray
        try {
            $acl = Get-Acl $dir
            $permission = "$env:COMPUTERNAME\$Username", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
            $acl.SetAccessRule($accessRule)
            Set-Acl $dir $acl -ErrorAction Stop
        } catch {
            Write-Host "  SKIP: Could not set permissions for $dir : $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  SKIP: User $Username does not exist, skipping permissions" -ForegroundColor Yellow
    }
}
Write-Host "OK Directories configured" -ForegroundColor Green

# 3. Check ports (open in Windows Firewall)
Write-Host "`n3. Checking Windows Firewall ports..." -ForegroundColor Yellow
$ruleName = "1C-CI-CD-Ports"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if (-not $existingRule) {
    if ($isAdmin) {
        Write-Host "  Creating firewall rule: $ruleName" -ForegroundColor Gray
        $portsStr = $Ports -join ','
        try {
            New-NetFirewallRule -DisplayName $ruleName `
                -Direction Inbound `
                -Action Allow `
                -Protocol TCP `
                -LocalPort $Ports `
                -Description "Open ports for CI/CD: GitLab (8929,2224), PostgreSQL (5432), SonarQube (9000), Redmine (3000), Scripts UI (8081)" `
                -ErrorAction Stop | Out-Null
            Write-Host "OK Firewall rule created for ports: $portsStr" -ForegroundColor Green
        } catch {
            Write-Host "FAILED: Could not create firewall rule: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "SKIP: Firewall rule creation requires Administrator rights" -ForegroundColor Yellow
    }
} else {
    Write-Host "OK Firewall rule already exists" -ForegroundColor Green
}

# 4. Check port availability
Write-Host "`n4. Checking port availability..." -ForegroundColor Yellow
$hostname = $env:COMPUTERNAME
foreach ($port in $Ports) {
    $result = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction SilentlyContinue
    $status = if ($result) { "BUSY" } else { "FREE" }
    $color = if ($result) { "Yellow" } else { "Green" }
    Write-Host "  Port $port : $status" -ForegroundColor $color
}

Write-Host "`n=== Stage 0 completed ===" -ForegroundColor Cyan
Write-Host "Hostname: $hostname" -ForegroundColor Gray
Write-Host "User: $Username (created/checked)" -ForegroundColor Gray
Write-Host "Permissions assigned to:" -ForegroundColor Gray
$Directories | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
$portsDisplay = $Ports -join ', '
Write-Host "Ports opened: $portsDisplay" -ForegroundColor Gray

