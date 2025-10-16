Write-Host "=== GitLab Runner Test ===" -ForegroundColor Cyan
Write-Host "Current time: $(Get-Date)" -ForegroundColor Gray
Write-Host "Current user: $env:USERNAME" -ForegroundColor Gray
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray
Write-Host "GitLab CI variables:" -ForegroundColor Gray
Write-Host "  CI_PROJECT_NAME: $env:CI_PROJECT_NAME" -ForegroundColor Gray
Write-Host "  CI_COMMIT_SHA: $env:CI_COMMIT_SHA" -ForegroundColor Gray
Write-Host "  CI_PIPELINE_ID: $env:CI_PIPELINE_ID" -ForegroundColor Gray
Write-Host "=== Test completed successfully ===" -ForegroundColor Green
