# scripts/logs.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Streaming logs for Spaces services (Press Ctrl+C to exit)..." -ForegroundColor Cyan
pm2 logs --lines 50
