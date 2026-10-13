Option Explicit
Dim shell, files, folder, powerShell, scriptPath, command, result
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")
folder = files.GetParentFolderName(WScript.ScriptFullName)
powerShell = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
scriptPath = files.BuildPath(folder, "update.ps1")
command = """" & powerShell & """ -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptPath & """"
' Hide at process creation, before PowerShell can allocate a visible console.
' Wait and propagate the updater exit code so Task Scheduler reports failures.
result = shell.Run(command, 0, True)
WScript.Quit result
