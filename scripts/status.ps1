# scripts/status.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Spaces Services Status:" -ForegroundColor Cyan
pm2 status
