# ============================================================================
#  Installeur / lanceur du Biblio-Tech Widget (kit distribué via GitHub).
#  1. Si la copie locale (%LOCALAPPDATA%\BiblioTech-Widget\app) est absente
#     (ou -Repair) : lit latest.json sur GitHub, télécharge le zip de la release,
#     vérifie son empreinte SHA-256, l'installe, puis crée les raccourcis
#     (menu Démarrer + Bureau) vers la copie locale.
#  2. Lance l'application locale.
#  Ensuite, les mises à jour se font DANS l'application (pastille « Mise à jour »),
#  exactement comme le SNOW Widget : on ne force pas la MAJ ici.
#  Dépôt PUBLIC : aucun jeton, aucun identifiant.
# ============================================================================
param([switch]$Repair, [string]$Repo = 'Lixirian/Biblio-Tech-Widget', [string]$Branch = 'main')
$ErrorActionPreference = 'Stop'
$dataDir = Join-Path $env:LOCALAPPDATA 'BiblioTech-Widget'
$appDir  = Join-Path $dataDir 'app'
$log     = Join-Path $dataDir 'app_debug.log'
$entry   = Join-Path $appDir 'Start-BiblioTech.vbs'

function L([string]$m) {
    try {
        if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
        Add-Content -LiteralPath $log -Value ("{0} [LANCEUR] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8
    } catch { }
    Write-Host "  $m"
}

function New-WebClient {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = 'BiblioTech-Widget-Installer'
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $wc.Proxy = $proxy
    $wc.Encoding = [System.Text.Encoding]::UTF8
    return $wc
}

function New-Shortcut([string]$Lnk) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($Lnk)
    $sc.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $sc.Arguments = '"' + $entry + '"'
    $sc.WorkingDirectory = $appDir
    $ico = Join-Path $appDir 'icone app.ico'
    $sc.IconLocation = if (Test-Path $ico) { "$ico,0" } else { "$env:WINDIR\System32\imageres.dll,186" }
    $sc.Description = 'Biblio-Tech Widget - recherche dans la base de connaissances KM'
    $sc.Save()
}

try {
    Write-Host ''
    Write-Host '  Biblio-Tech Widget' -ForegroundColor Cyan
    Write-Host '  ------------------' -ForegroundColor DarkCyan
    if ($Repair -or -not (Test-Path -LiteralPath $entry)) {
        L 'Installation de la dernière version depuis GitHub...'
        $wc = New-WebClient
        $raw = $wc.DownloadString(('https://raw.githubusercontent.com/{0}/{1}/latest.json?t={2}' -f $Repo, $Branch, [DateTime]::UtcNow.Ticks))
        $m = $raw.TrimStart([char]0xFEFF) | ConvertFrom-Json
        $url = [string]$m.url
        if (-not $url) { $url = 'https://github.com/{0}/releases/download/v{1}/{2}' -f $Repo, $m.version, $m.zip }
        L "Version $($m.version) : téléchargement..."
        $tmpZip = Join-Path $env:TEMP ('biblio_' + [guid]::NewGuid().ToString('N') + '.zip')
        $wc.DownloadFile($url, $tmpZip)
        $sha = (Get-FileHash -LiteralPath $tmpZip -Algorithm SHA256).Hash
        if ($m.sha256 -and $sha -ne ([string]$m.sha256).ToUpperInvariant()) { throw "empreinte SHA-256 invalide (fichier corrompu ou altéré)" }
        $tmp = Join-Path $env:TEMP ('biblio_' + [guid]::NewGuid().ToString('N'))
        Expand-Archive -LiteralPath $tmpZip -DestinationPath $tmp -Force
        $inner = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'BiblioTechWidget.ps1') } | Select-Object -First 1
        $src = if ($inner) { $inner.FullName } else { $tmp }
        if (-not (Test-Path (Join-Path $src 'BiblioTechWidget.ps1'))) { throw 'archive invalide' }
        if (-not (Test-Path $appDir)) { New-Item -ItemType Directory -Path $appDir -Force | Out-Null }
        Copy-Item -Path (Join-Path $src '*') -Destination $appDir -Recurse -Force
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
        L "Version $($m.version) installée dans $appDir."

        # Raccourcis vers la COPIE LOCALE (plus besoin de ce lanceur ensuite).
        try {
            New-Shortcut (Join-Path ([Environment]::GetFolderPath('Programs')) 'Biblio-Tech Widget.lnk')
            New-Shortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Biblio-Tech Widget.lnk')
            L 'Raccourcis créés (menu Démarrer + Bureau).'
        } catch { L "Raccourcis non créés : $($_.Exception.Message)" }
    }

    if (Test-Path -LiteralPath $entry) {
        Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $entry + '"') -WorkingDirectory $appDir
        L 'Application lancée (raccourci clavier : Ctrl+Alt+K).'
        Start-Sleep -Seconds 2
    } else { throw "aucune version installée dans $appDir" }
} catch {
    L ("ECHEC : " + $_.Exception.Message)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Installation impossible : $($_.Exception.Message)`n`nVérifiez l'accès à github.com (réseau / proxy) puis relancez.`nJournal : $log",
        'Biblio-Tech Widget', 'OK', 'Error') | Out-Null
}
