# scripts/restart-all.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Rebuilding backend..." -ForegroundColor Cyan
Push-Location (Join-Path $projectRoot "backend")
npm run build
Pop-Location

Write-Host "Restarting all Spaces services managed by PM2..." -ForegroundColor Cyan
pm2 restart node-backend python-ai
pm2 status
