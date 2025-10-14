# notify-redmine.ps1 - Send pipeline notifications to Redmine
param(
    [string]$RedmineUrl = "http://localhost:3000",
    [string]$RedmineApiKey,
    [string]$PipelineStatus = "success",
    [string]$CommitMessage = "",
    [string]$PipelineUrl = $env:CI_PIPELINE_URL,
    [string]$CommitSha = $env:CI_COMMIT_SHORT_SHA
)

$ErrorActionPreference = 'Continue'

Write-Host "=== Sending Redmine Notifications ===" -ForegroundColor Cyan

# Extract issue number from commit message (e.g., #123, refs #456, issue-789)
$issuePattern = '(?:#|refs\s+#|issue-?)(\d+)'
$matches = [regex]::Matches($CommitMessage, $issuePattern)

if ($matches.Count -eq 0) {
    Write-Host "No Redmine issue reference found in commit message" -ForegroundColor Yellow
    Write-Host "Commit message: $CommitMessage" -ForegroundColor Gray
    exit 0
}

$issueNumbers = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

Write-Host "Found issue references: $($issueNumbers -join ', ')" -ForegroundColor Gray

# Prepare headers
$headers = @{
    "X-Redmine-API-Key" = $RedmineApiKey
    "Content-Type" = "application/json"
}

# Prepare comment
$statusEmoji = switch ($PipelineStatus) {
    "success" { "✓" }
    "failed" { "✗" }
    "warning" { "⚠" }
    default { "•" }
}

$comment = @"
h4. $statusEmoji CI/CD Pipeline $PipelineStatus

* *Commit:* @$CommitSha@
* *Status:* *$PipelineStatus*
* *Pipeline:* $PipelineUrl
* *Message:* $CommitMessage

_Automated notification from CI/CD pipeline_
"@

# Post comment to each issue
foreach ($issueNum in $issueNumbers) {
    try {
        $body = @{
            issue = @{
                notes = $comment
            }
        } | ConvertTo-Json -Depth 3
        
        $response = Invoke-RestMethod `
            -Uri "$RedmineUrl/issues/$issueNum.json" `
            -Headers $headers `
            -Method Put `
            -Body $body `
            -UseBasicParsing
        
        Write-Host "✓ Comment posted to issue #$issueNum" -ForegroundColor Green
        
    } catch {
        Write-Host "✗ Failed to post to issue #$issueNum : $_" -ForegroundColor Red
    }
}

Write-Host "=== Notifications completed ===" -ForegroundColor Cyan

