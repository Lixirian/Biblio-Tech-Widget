' ============================================================
'  Biblio-Tech Widget - lanceur SANS fenetre console.
'  Demarre PowerShell en fenetre cachee (STA requis par WPF).
' ============================================================
Option Explicit
Dim shell, fso, scriptDir, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & scriptDir & "\BiblioTechWidget.ps1"""
shell.Run cmd, 0, False