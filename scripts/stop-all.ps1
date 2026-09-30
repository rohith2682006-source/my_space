# scripts/stop-all.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Stopping all Spaces services managed by PM2..." -ForegroundColor Yellow
pm2 stop node-backend python-ai
pm2 status
