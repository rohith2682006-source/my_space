# scripts/start-all.ps1
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Spaces Platform Services" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Create logs directory if needed
$logsDir = Join-Path $projectRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Verify backend compilation
$backendDist = Join-Path $projectRoot "backend\dist\index.js"
if (-not (Test-Path $backendDist)) {
    Write-Host "Building Node.js backend..." -ForegroundColor Yellow
    Push-Location (Join-Path $projectRoot "backend")
    npm run build
    Pop-Location
}

# Start ecosystem using PM2
pm2 start ecosystem.config.js
pm2 save
Write-Host ""
Write-Host "Current PM2 status:" -ForegroundColor Green
pm2 status
