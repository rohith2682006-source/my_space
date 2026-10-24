# scripts/launch-spaces.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot

# 1. Start Node.js backend on :3000 if not already running
$nodeRunning = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $nodeRunning) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npx tsx src/index.ts" -WorkingDirectory "$projectRoot\backend" -WindowStyle Hidden
}

# 2. Start Python AI service on :8000 if not already running
$aiRunning = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if (-not $aiRunning) {
    Start-Process -FilePath "$projectRoot\ai_service\.venv\Scripts\python.exe" -ArgumentList "-m uvicorn main:app --host 127.0.0.1 --port 8000" -WorkingDirectory "$projectRoot\ai_service" -WindowStyle Hidden
}

# 3. Wait briefly for services to spin up if they were just started
$attempts = 10
while ($attempts -gt 0 -and (-not (Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue) -or -not (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue))) {
    Start-Sleep -Milliseconds 400
    $attempts--
}

# 4. Find most recent desktop executable
$releaseExe = "$projectRoot\spaces_app\build\windows\x64\runner\Release\spaces_app.exe"
$debugExe = "$projectRoot\spaces_app\build\windows\x64\runner\Debug\spaces_app.exe"

$targetExe = $null
if ((Test-Path $releaseExe) -and (Test-Path $debugExe)) {
    $relTime = (Get-Item $releaseExe).LastWriteTime
    $debTime = (Get-Item $debugExe).LastWriteTime
    if ($debTime -gt $relTime) {
        $targetExe = $debugExe
    } else {
        $targetExe = $releaseExe
    }
} elseif (Test-Path $releaseExe) {
    $targetExe = $releaseExe
} elseif (Test-Path $debugExe) {
    $targetExe = $debugExe
}

# 5. Launch Spaces app if not already open
if ($targetExe) {
    $appProc = Get-Process -Name "spaces_app" -ErrorAction SilentlyContinue
    if (-not $appProc) {
        Start-Process -FilePath $targetExe -WorkingDirectory (Split-Path $targetExe)
    }
}
