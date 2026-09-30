# scripts/remove-windows-startup.ps1
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$startupFile = Join-Path $startupFolder "spaces-pm2-startup.cmd"

if (Test-Path $startupFile) {
    Remove-Item -Path $startupFile -Force
    Write-Host "SUCCESS: Windows startup launcher removed: $startupFile" -ForegroundColor Green
} else {
    Write-Host "Windows startup launcher was not installed." -ForegroundColor Yellow
}
