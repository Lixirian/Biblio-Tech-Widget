' ============================================================
'  Biblio-Tech Widget - lanceur des raccourcis, SANS console.
'  Copie installee dans %LOCALAPPDATA%\BiblioTech-Widget\launcher\.
'  Execute bootstrap.ps1 : mise a jour / reparation automatique
'  si besoin, puis lancement de l'application.
' ============================================================
Option Explicit
Dim shell, fso, scriptDir, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\bootstrap.ps1"""
shell.Run cmd, 0, False
