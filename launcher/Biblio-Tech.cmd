@echo off
REM ============================================================
REM  Biblio-Tech Widget - installation / lancement.
REM  1er lancement : telecharge la derniere version depuis GitHub
REM  et l'installe dans %LOCALAPPDATA%\BiblioTech-Widget\app,
REM  puis cree les raccourcis (menu Demarrer + Bureau).
REM  Si une version est deja installee mais ancienne ou abimee,
REM  elle est mise a jour / reparee automatiquement.
REM  Ensuite : utiliser le raccourci (meme verification a chaque
REM  lancement). Forcer une reinstallation : "Biblio-Tech.cmd /repair"
REM ============================================================
set "BTARGS="
if /i "%~1"=="/repair" set "BTARGS=-Repair"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %BTARGS%