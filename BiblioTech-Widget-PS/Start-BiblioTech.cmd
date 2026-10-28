@echo off
REM ============================================================
REM  Biblio-Tech Widget - lanceur de la copie locale (passe par
REM  le .vbs pour n'avoir AUCUNE fenetre console).
REM ============================================================
cd /d "%~dp0"
start "" "%SystemRoot%\System32\wscript.exe" "%~dp0Start-BiblioTech.vbs"