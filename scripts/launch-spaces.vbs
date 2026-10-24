Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = fso.BuildPath(scriptDir, "launch-spaces.ps1")
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psScript & """", 0, False
