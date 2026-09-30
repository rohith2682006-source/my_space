# scripts/setup-windows-startup.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Configuring Windows Startup for Spaces" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 1. Save current PM2 processes to dump.pm2
Write-Host "Saving active PM2 processes..." -ForegroundColor Yellow
pm2 save

# 2. Path to Windows User Startup folder
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$startupFile = Join-Path $startupFolder "spaces-pm2-startup.cmd"

# 3. Create startup runner script
$content = @"
@echo off
REM Auto-start Spaces services on Windows logon via PM2 resurrect
echo Starting Spaces services...
call pm2 resurrect
"@

Set-Content -Path $startupFile -Value $content -Encoding ASCII

Write-Host ""
Write-Host "SUCCESS: Windows startup registered!" -ForegroundColor Green
Write-Host "Startup file created at:"
Write-Host "  $startupFile" -ForegroundColor Yellow
Write-Host "Whenever you log in to Windows, PM2 will automatically resurrect and run both services."
Write-Host ""
