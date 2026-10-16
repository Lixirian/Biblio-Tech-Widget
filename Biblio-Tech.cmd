@echo off
REM ============================================================
REM  Biblio-Tech Widget - UN SEUL FICHIER : double-cliquer.
REM  Installe la derniere version depuis GitHub si besoin, la
REM  met a jour ou la repare, cree les raccourcis puis lance
REM  l'application. Aucun .exe, aucun identifiant stocke.
REM  Forcer une reinstallation : "Biblio-Tech.cmd /repair"
REM  Fichier GENERE par build-release.ps1 (launcher\bootstrap.ps1).
REM ============================================================
setlocal
set "BT_SELF=%~f0"
set "BTARGS="
if /i "%~1"=="/repair" set "BTARGS=-Repair"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:BT_SELF,[Text.Encoding]::UTF8); $i=$s.IndexOf('#'+'#BIBLIOTECH-PS#'+'#'); & ([ScriptBlock]::Create($s.Substring($i))) %BTARGS%"
exit /b
##BIBLIOTECH-PS##
# ============================================================================
#  Installeur / lanceur du Biblio-Tech Widget (distribué via GitHub).
#  Exécuté à CHAQUE lancement (raccourcis -> %LOCALAPPDATA%\BiblioTech-Widget\
#  launcher\Biblio-Tech.vbs, sans console) et embarqué tel quel dans
#  Biblio-Tech.cmd (fichier unique généré par build-release.ps1).
#  1. Lit latest.json sur GitHub (délai court ; hors ligne -> on lance l'existant).
#  2. Installe / répare AUTOMATIQUEMENT si la copie locale est absente, abîmée,
#     plus ancienne que la version publiée, ou si -Repair : arrêt de l'instance
#     en cours, téléchargement, contrôle SHA-256, copie.
#  3. Met à jour ce lanceur et les raccourcis, puis lance l'application.
#  Dépôt PUBLIC : aucun jeton, aucun identifiant.
# ============================================================================
param([switch]$Repair, [string]$Repo = 'Lixirian/Biblio-Tech-Widget', [string]$Branch = 'main')
$ErrorActionPreference = 'Stop'
$dataDir  = Join-Path $env:LOCALAPPDATA 'BiblioTech-Widget'
$appDir   = Join-Path $dataDir 'app'
$lchDir   = Join-Path $dataDir 'launcher'
$log      = Join-Path $dataDir 'app_debug.log'
$entry    = Join-Path $appDir 'Start-BiblioTech.vbs'
$lchVbs   = Join-Path $lchDir 'Biblio-Tech.vbs'

function L([string]$m) {
    try {
        if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
        Add-Content -LiteralPath $log -Value ("{0} [LANCEUR] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8
    } catch { }
    Write-Host "  $m"
}

function Get-Proxy {
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    return $proxy
}

function New-WebClient {
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = 'BiblioTech-Widget-Installer'
    $wc.Proxy = Get-Proxy
    $wc.Encoding = [System.Text.Encoding]::UTF8
    return $wc
}

# Manifeste latest.json avec un délai court : au lancement, on ne fait pas attendre.
function Get-Manifest([int]$TimeoutMs) {
    $rq = [System.Net.HttpWebRequest]::Create(('https://raw.githubusercontent.com/{0}/{1}/latest.json?t={2}' -f $Repo, $Branch, [DateTime]::UtcNow.Ticks))
    $rq.Timeout = $TimeoutMs; $rq.ReadWriteTimeout = $TimeoutMs
    $rq.UserAgent = 'BiblioTech-Widget-Installer'
    $rq.Proxy = Get-Proxy
    $rs = $rq.GetResponse()
    try {
        $sr = New-Object System.IO.StreamReader($rs.GetResponseStream(), [System.Text.Encoding]::UTF8)
        return ($sr.ReadToEnd().TrimStart([char]0xFEFF) | ConvertFrom-Json)
    } finally { $rs.Close() }
}

# Compare deux versions « x.y.z » numériquement. -1 / 0 / 1.
function Compare-Version([string]$A, [string]$B) {
    $pa = @(([string]$A -split '\.') | ForEach-Object { [int]('0' + ($_ -replace '\D', '')) })
    $pb = @(([string]$B -split '\.') | ForEach-Object { [int]('0' + ($_ -replace '\D', '')) })
    for ($i = 0; $i -lt [Math]::Max($pa.Count, $pb.Count); $i++) {
        $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($x -ne $y) { return $(if ($x -gt $y) { 1 } else { -1 }) }
    }
    return 0
}

# Version installée ('' si aucune) et état des fichiers indispensables.
function Get-InstalledVersion {
    $cfg = Join-Path $appDir 'config.ps1'
    if (-not (Test-Path -LiteralPath $cfg)) { return '' }
    try { return [regex]::Match((Get-Content -LiteralPath $cfg -Raw -Encoding UTF8), "Version\s*=\s*'([^']+)'").Groups[1].Value } catch { return '' }
}
function Test-InstallHealthy {
    foreach ($f in @('BiblioTechWidget.ps1', 'config.ps1', 'Start-BiblioTech.vbs', 'lib\BtCommon.ps1', 'lib\BtNet.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $appDir $f))) { return $false }
    }
    return $true
}

# Arrête l'instance en cours (sinon les DLL WebView2 sont verrouillées pendant la copie).
function Stop-RunningApp {
    $target = (Join-Path $appDir 'BiblioTechWidget.ps1')
    $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine.IndexOf($target, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    foreach ($p in $procs) {
        L "Arrêt de l'instance en cours (PID $($p.ProcessId)) pour la mise à jour."
        try { Stop-Process -Id $p.ProcessId -Force } catch { }
    }
    if ($procs.Count) { Start-Sleep -Seconds 2 }
}

function Install-App($m) {
    $url = [string]$m.url
    if (-not $url) { $url = 'https://github.com/{0}/releases/download/v{1}/{2}' -f $Repo, $m.version, $m.zip }
    L "Version $($m.version) : téléchargement..."
    $tmpZip = Join-Path $env:TEMP ('biblio_' + [guid]::NewGuid().ToString('N') + '.zip')
    (New-WebClient).DownloadFile($url, $tmpZip)
    $sha = (Get-FileHash -LiteralPath $tmpZip -Algorithm SHA256).Hash
    if ($m.sha256 -and $sha -ne ([string]$m.sha256).ToUpperInvariant()) { throw "empreinte SHA-256 invalide (fichier corrompu ou altéré)" }
    $tmp = Join-Path $env:TEMP ('biblio_' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmp -Force
    $inner = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'BiblioTechWidget.ps1') } | Select-Object -First 1
    $src = if ($inner) { $inner.FullName } else { $tmp }
    if (-not (Test-Path (Join-Path $src 'BiblioTechWidget.ps1'))) { throw 'archive invalide' }
    Stop-RunningApp
    if (-not (Test-Path $appDir)) { New-Item -ItemType Directory -Path $appDir -Force | Out-Null }
    # Quelques essais : un processus WebView2 peut libérer ses fichiers avec retard.
    for ($i = 1; $i -le 5; $i++) {
        try { Copy-Item -Path (Join-Path $src '*') -Destination $appDir -Recurse -Force; break }
        catch { if ($i -eq 5) { throw }; Start-Sleep -Seconds 2 }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
    L "Version $($m.version) installée dans $appDir."
}

# Copie le lanceur hors du dossier app (il survit à une copie abîmée) et y fait
# pointer les raccourcis. Source : app\launcher (livré avec chaque version), sinon ce script.
function Install-Launcher {
    if (-not (Test-Path $lchDir)) { New-Item -ItemType Directory -Path $lchDir -Force | Out-Null }
    $srcDir = Join-Path $appDir 'launcher'
    # Exécuté depuis Biblio-Tech.cmd (script embarqué), $PSScriptRoot est vide : seule la source app\launcher compte.
    if (-not (Test-Path (Join-Path $srcDir 'bootstrap.ps1'))) { $srcDir = $PSScriptRoot }
    if (-not $srcDir) { $srcDir = $lchDir }
    foreach ($f in @('bootstrap.ps1', 'Biblio-Tech.vbs')) {
        $s = Join-Path $srcDir $f; $d = Join-Path $lchDir $f
        if ((Test-Path $s) -and ([IO.Path]::GetFullPath($s) -ne [IO.Path]::GetFullPath($d))) { Copy-Item -LiteralPath $s -Destination $d -Force }
    }
    if (-not (Test-Path $lchVbs)) { return }
    $wsh = New-Object -ComObject WScript.Shell
    $ico = Join-Path $appDir 'icone app.ico'
    $links = @(
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'Biblio-Tech Widget.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Biblio-Tech Widget.lnk')
    )
    $startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Biblio-Tech Widget.lnk'
    if (Test-Path $startup) { $links += $startup }      # démarrage auto : seulement s'il était activé
    foreach ($lnk in $links) {
        try {
            $sc = $wsh.CreateShortcut($lnk)
            $sc.TargetPath = "$env:WINDIR\System32\wscript.exe"
            $sc.Arguments = '"' + $lchVbs + '"'
            $sc.WorkingDirectory = $lchDir
            $sc.IconLocation = if (Test-Path $ico) { "$ico,0" } else { "$env:WINDIR\System32\imageres.dll,186" }
            $sc.Description = 'Biblio-Tech - recherche dans la base de connaissances'
            $sc.Save()
        } catch { L "Raccourci non créé ($lnk) : $($_.Exception.Message)" }
    }
}

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    Write-Host ''
    Write-Host '  Biblio-Tech Widget' -ForegroundColor Cyan
    Write-Host '  ------------------' -ForegroundColor DarkCyan
    $installed = Get-InstalledVersion
    $healthy = Test-InstallHealthy
    # Installation existante saine : délai court (lancement rapide) ; sinon on attend GitHub.
    $m = $null
    try { $m = Get-Manifest $(if ($healthy) { 5000 } else { 20000 }) }
    catch { L "GitHub injoignable ($($_.Exception.Message))." }

    $reason = if ($Repair) { 'réparation demandée' }
              elseif (-not $installed) { 'première installation' }
              elseif (-not $healthy) { 'installation incomplète' }
              elseif ($m -and (Compare-Version $installed ([string]$m.version)) -lt 0) { "mise à jour $installed -> $($m.version)" }
              else { '' }
    if ($reason) {
        if (-not $m) {
            if (-not $healthy) { throw 'impossible de télécharger l''application (GitHub injoignable)' }
            L "Réparation impossible hors ligne : lancement de la version $installed."
        } else {
            L "Installation automatique : $reason."
            Install-App $m
        }
    }
    try { Install-Launcher } catch { L "Lanceur non mis à jour : $($_.Exception.Message)" }

    if (Test-Path -LiteralPath $entry) {
        Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $entry + '"') -WorkingDirectory $appDir
        L 'Application lancée (raccourci clavier : Ctrl+Alt+K).'
    } else { throw "aucune version installée dans $appDir" }
} catch {
    L ("ECHEC : " + $_.Exception.Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Installation impossible : $($_.Exception.Message)`n`nVérifiez l'accès à github.com (réseau / proxy) puis relancez.`nJournal : $log",
        'Biblio-Tech Widget', 'OK', 'Error') | Out-Null
}
