# scripts/create-desktop-shortcut.ps1
$projectRoot = Split-Path -Parent $PSScriptRoot

$desktopFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$shortcutPath = Join-Path $desktopFolder "Spaces.lnk"

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$projectRoot\scripts\launch-spaces.vbs`""
$shortcut.WorkingDirectory = "$projectRoot"

$iconPath = "$projectRoot\spaces_app\windows\runner\resources\app_icon.ico"
if (Test-Path $iconPath) {
    $shortcut.IconLocation = "$iconPath,0"
}

$shortcut.Description = "Launch Spaces Platform (Backend + AI + App)"
$shortcut.Save()

Write-Host "Created Desktop Shortcut at: $shortcutPath" -ForegroundColor Green

# Also configure Windows Startup so backend & AI are already running on boot (Zero wait time)
$startupFolder = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\Windows\Start Menu\Programs\Startup")
$startupVbsPath = Join-Path $startupFolder "spaces-services-startup.vbs"

$startupVbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
projectRoot = "$projectRoot"
psScript = projectRoot & "\scripts\launch-spaces.ps1"
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psScript & """", 0, False
"@

Set-Content -Path $startupVbsPath -Value $startupVbsContent -Encoding ASCII
Write-Host "Configured Windows Startup runner at: $startupVbsPath" -ForegroundColor Green
