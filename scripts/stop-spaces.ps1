# scripts/stop-spaces.ps1

# 1. Stop spaces_app if running
Stop-Process -Name "spaces_app" -Force -ErrorAction SilentlyContinue

# 2. Stop Node backend on :3000
$nodePort = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($nodePort) {
    Stop-Process -Id $nodePort.OwningProcess -Force -ErrorAction SilentlyContinue
}

# 3. Stop Python AI on :8000
$aiPort = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($aiPort) {
    Stop-Process -Id $aiPort.OwningProcess -Force -ErrorAction SilentlyContinue
}

Write-Host "All Spaces services stopped." -ForegroundColor Green
