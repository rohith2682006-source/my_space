# scripts/start-ai.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $projectRoot "ai_service")
Write-Host "Starting Spaces Python AI service on http://127.0.0.1:8000..." -ForegroundColor Cyan
& ".\.venv\Scripts\python.exe" -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
