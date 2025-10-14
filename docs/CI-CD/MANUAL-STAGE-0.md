# Manual Stage 0 Setup - OS Prerequisites

## Required Actions (Administrator Rights)

Stage 0 requires Administrator privileges. Please run the following steps manually:

### Option 1: Run prep-os script as Administrator

1. Open PowerShell as Administrator (Right-click -> Run as Administrator)
2. Navigate to project directory:
   ```powershell
   cd C:\1C-CI-CD
   ```
3. Run the script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File ci/scripts/prep-os.ps1
   ```

### Option 2: Manual setup

If you prefer manual setup, perform these steps:

#### 1. Create ci_1c user
```powershell
# Run in PowerShell as Administrator
$Password = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
New-LocalUser -Name "ci_1c" -Password $Password -PasswordNeverExpires -Description "CI/CD 1C Service User"
```

#### 2. Grant permissions to directories
```powershell
# Run in PowerShell as Administrator
$dirs = @("C:\1crepository", "C:\1C-CI-CD", "C:\1C-CI-CD\build")
foreach ($dir in $dirs) {
    $acl = Get-Acl $dir
    $permission = "$env:COMPUTERNAME\ci_1c", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $dir $acl
}
```

#### 3. Open firewall ports
```powershell
# Run in PowerShell as Administrator
New-NetFirewallRule -DisplayName "1C-CI-CD-Ports" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 8929,2224,5432,9000,3000,8081 `
    -Description "Open ports for CI/CD: GitLab (8929,2224), PostgreSQL (5432), SonarQube (9000), Redmine (3000), Scripts UI (8081)"
```

## Verification

After setup, verify:
```powershell
# Check user exists
Get-LocalUser -Name ci_1c

# Check firewall rule
Get-NetFirewallRule -DisplayName "1C-CI-CD-Ports"
```

## Note

The automated setup will continue with Stage 2 (PostgreSQL in Docker) which does not require Administrator rights.
Stage 4 (GitLab Runner registration) will also require Administrator rights or manual setup.

