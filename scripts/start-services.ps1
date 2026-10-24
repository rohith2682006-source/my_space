# scripts/start-services.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot

# 1. Start Node.js backend on :3000 if not running
$nodeRunning = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $nodeRunning) {
    Write-Host "Starting Node backend on port 3000..." -ForegroundColor Cyan
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npx tsx src/index.ts" -WorkingDirectory "$projectRoot\backend" -WindowStyle Hidden
} else {
    Write-Host "Node backend is already running on port 3000." -ForegroundColor Green
}

# 2. Start Python AI service on :8000 if not running
$aiRunning = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if (-not $aiRunning) {
    Write-Host "Starting Python AI service on port 8000..." -ForegroundColor Cyan
    Start-Process -FilePath "$projectRoot\ai_service\.venv\Scripts\python.exe" -ArgumentList "-m uvicorn main:app --host 127.0.0.1 --port 8000" -WorkingDirectory "$projectRoot\ai_service" -WindowStyle Hidden
} else {
    Write-Host "Python AI service is already running on port 8000." -ForegroundColor Green
}

# 3. Wait up to 5 seconds to confirm both are healthy
$attempts = 10
while ($attempts -gt 0 -and (-not (Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue) -or -not (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue))) {
    Start-Sleep -Milliseconds 500
    $attempts--
}

Write-Host "Both services are active and running in the background!" -ForegroundColor Green
