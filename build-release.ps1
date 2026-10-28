# ============================================================================
#  Publie une version du Biblio-Tech Widget sur GitHub.
#   1. Lit la version (BiblioTech-Widget-PS\config.ps1) et ses notes
#      (BiblioTech-Widget-PS\releases.json).
#   2. Fabrique dist\BiblioTech-Widget_version<X>.zip (dossier racine interne du
#      même nom) + dist\BiblioTech-Installer.zip (kit lanceur) ; les anciens zips
#      de version partent dans Archives\.
#   3. Commit + push du code, création de la release GitHub v<X> (assets = zips).
#   4. SEULEMENT ENSUITE : écrit latest.json (version, url, sha256, notes) puis
#      commit + push -> les postes voient la pastille « Mise à jour ».
#      (Ordre volontaire : latest.json n'annonce jamais un zip pas encore en ligne.)
#  SIGNATURE : chaque version est signée (RSA 3072, SHA-256) avec une clé PRIVÉE qui ne
#  quitte jamais ce poste : %USERPROFILE%\.biblio-tech-signing\ (chiffrée par DPAPI pour
#  l'utilisateur Windows courant ; JAMAIS dans le dépôt, GitHub ou SynologyDrive). Le texte
#  signé est « BiblioTech-Widget|<version>|<SHA-256 du zip> » ; la signature va dans
#  latest.json (champ sig). L'appli et le lanceur embarquent la clé PUBLIQUE et refusent
#  tout zip non signé par elle : un compte GitHub compromis ne suffit plus à diffuser une MISE À
#  JOUR. Limite : Biblio-Tech.cmd (1re installation) n'est pas signé lui-même -> le diffuser par
#  un canal interne (voir la note DSI) ; seuls les fichiers suivis par Git sont empaquetés.
#  Usage :  powershell -ExecutionPolicy Bypass -File build-release.ps1 [-NoPublish]
#           ... -NewSigningKey  : crée la clé (une seule fois) et inscrit la clé publique dans
#                                 config.ps1 et launcher\bootstrap.ps1. Clé perdue = les postes
#                                 refuseront les MAJ : redistribuer Biblio-Tech.cmd.
#           ... -ExportSigningKey [-KeyBackup <fichier>] : SAUVEGARDE de la clé, chiffrée par un
#                                 mot de passe (AES-256, PBKDF2-SHA256 600 000 itérations) ; à garder
#                                 sur une clé USB / un gestionnaire de mots de passe (pas sur GitHub).
#           ... -ImportSigningKey -KeyBackup <fichier> : nouveau PC -> restaure la clé (mot de passe
#                                 demandé, contrôle qu'elle correspond à la clé publique livrée).
#  Prérequis : git + gh authentifié (gh auth login) avec droits sur le dépôt.
# ============================================================================
param([switch]$NoPublish, [switch]$SkipDocCheck, [switch]$NewSigningKey, [switch]$ExportSigningKey, [switch]$ImportSigningKey, [string]$KeyBackup = '')
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$src  = Join-Path $repo 'BiblioTech-Widget-PS'
$dist = Join-Path $repo 'dist'

# --- Clé de signature des versions --------------------------------------------
Add-Type -AssemblyName System.Security
$keyDir  = Join-Path $env:USERPROFILE '.biblio-tech-signing'
$keyFile = Join-Path $keyDir 'release-key.dpapi'
$pubFiles = @((Join-Path $src 'config.ps1'), (Join-Path $repo 'launcher\bootstrap.ps1'))
function New-BtRsa { $p = New-Object System.Security.Cryptography.CspParameters 24; return New-Object System.Security.Cryptography.RSACryptoServiceProvider(3072, $p) }
if ($NewSigningKey) {
    if (Test-Path -LiteralPath $keyFile) { throw "Une clé existe déjà ($keyFile). La remplacer couperait les mises à jour des postes : supprimez-la d'abord si c'est voulu." }
    $rsa = New-BtRsa
    $priv = [Text.Encoding]::UTF8.GetBytes($rsa.ToXmlString($true))
    New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
    [IO.File]::WriteAllBytes($keyFile, [Security.Cryptography.ProtectedData]::Protect($priv, $null, 'CurrentUser'))
    $pub = $rsa.ToXmlString($false)
    foreach ($f in $pubFiles) {
        $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
        $t2 = [regex]::Replace($t, "(ReleasePublicKey\s*=\s*)'[^']*'", ('${1}' + "'" + $pub + "'"))
        if ($t2 -eq $t) { throw "ReleasePublicKey introuvable dans $f" }
        [IO.File]::WriteAllText($f, $t2, (New-Object Text.UTF8Encoding $true))
    }
    Write-Host "Clé de signature créée : $keyFile (chiffrée DPAPI). Clé publique inscrite dans config.ps1 et bootstrap.ps1." -ForegroundColor Green
    return
}
# Sauvegarde : 'BTKEY1' | sel (16) | IV (16) | AES-256-CBC(clé XML) | HMAC-SHA256 (32) du tout.
function Read-BtSecret([string]$Prompt) {
    $s = Read-Host $Prompt -AsSecureString
    $p = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($p) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p) }   # copie non managée effacée
}
function Get-BtBackupKeys([byte[]]$Salt, [switch]$Confirm) {
    $plain = Read-BtSecret 'Mot de passe de la sauvegarde'
    if ($plain.Length -lt 12) { throw 'Mot de passe trop court (12 caractères minimum).' }
    if ($Confirm -and (Read-BtSecret 'Confirmez le mot de passe') -ne $plain) { throw 'Les deux mots de passe diffèrent.' }
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($plain, $Salt, 600000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $b = $kdf.GetBytes(64)
    return @{ Aes = $b[0..31]; Mac = $b[32..63] }
}
if ($ExportSigningKey) {
    if (-not (Test-Path -LiteralPath $keyFile)) { throw "Aucune clé à sauvegarder ($keyFile)." }
    if (-not $KeyBackup) { $KeyBackup = Join-Path ([Environment]::GetFolderPath('Desktop')) 'biblio-tech-signing-key.backup' }
    if (Test-Path -LiteralPath $KeyBackup) { throw "$KeyBackup existe déjà." }
    $plainKey = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($keyFile), $null, 'CurrentUser')
    $salt = New-Object byte[] 16; $iv = New-Object byte[] 16
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider; $rng.GetBytes($salt); $rng.GetBytes($iv)
    $k = Get-BtBackupKeys $salt -Confirm
    $aes = [System.Security.Cryptography.Aes]::Create(); $aes.Key = [byte[]]$k.Aes; $aes.IV = $iv
    $ct = $aes.CreateEncryptor().TransformFinalBlock($plainKey, 0, $plainKey.Length)
    $body = [byte[]]([Text.Encoding]::ASCII.GetBytes('BTKEY1') + $salt + $iv + $ct)
    $mac = (New-Object System.Security.Cryptography.HMACSHA256 (, [byte[]]$k.Mac)).ComputeHash($body)
    [IO.File]::WriteAllBytes($KeyBackup, [byte[]]($body + $mac))
    Write-Host "Sauvegarde chiffrée écrite : $KeyBackup" -ForegroundColor Green
    Write-Host 'Rangez-la HORS du dépôt et de GitHub (clé USB, gestionnaire de mots de passe) et notez le mot de passe.' -ForegroundColor Yellow
    return
}
if ($ImportSigningKey) {
    if (-not $KeyBackup -or -not (Test-Path -LiteralPath $KeyBackup)) { throw 'Indiquez la sauvegarde : -KeyBackup <fichier>.' }
    if (Test-Path -LiteralPath $keyFile) { throw "Une clé est déjà présente sur ce poste ($keyFile)." }
    $all = [IO.File]::ReadAllBytes($KeyBackup)
    if ($all.Length -lt 6 + 32 + 32 -or [Text.Encoding]::ASCII.GetString($all, 0, 6) -ne 'BTKEY1') { throw 'Fichier de sauvegarde invalide.' }
    $body = $all[0..($all.Length - 33)]; $mac = $all[($all.Length - 32)..($all.Length - 1)]
    $salt = $all[6..21]; $iv = $all[22..37]; $ct = [byte[]]$all[38..($all.Length - 33)]
    $k = Get-BtBackupKeys ([byte[]]$salt)
    $calc = (New-Object System.Security.Cryptography.HMACSHA256 (, [byte[]]$k.Mac)).ComputeHash([byte[]]$body)
    if ([Convert]::ToBase64String($calc) -ne [Convert]::ToBase64String([byte[]]$mac)) { throw 'Mot de passe incorrect ou sauvegarde altérée.' }
    $aes = [System.Security.Cryptography.Aes]::Create(); $aes.Key = [byte[]]$k.Aes; $aes.IV = [byte[]]$iv
    $plainKey = $aes.CreateDecryptor().TransformFinalBlock($ct, 0, $ct.Length)
    $rsa = New-BtRsa; $rsa.FromXmlString([Text.Encoding]::UTF8.GetString($plainKey))
    foreach ($f in $pubFiles) {
        $p = [regex]::Match([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8), "ReleasePublicKey\s*=\s*'([^']*)'").Groups[1].Value
        if ($p -ne $rsa.ToXmlString($false)) { throw "Cette clé ne correspond pas à la clé publique de $f : restauration annulée." }
    }
    New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
    [IO.File]::WriteAllBytes($keyFile, [Security.Cryptography.ProtectedData]::Protect($plainKey, $null, 'CurrentUser'))
    Write-Host "Clé restaurée sur ce poste : $keyFile" -ForegroundColor Green
    return
}
if (-not (Test-Path -LiteralPath $keyFile)) { throw "Clé de signature introuvable ($keyFile). Première fois : -NewSigningKey ; nouveau PC : -ImportSigningKey -KeyBackup <fichier>." }
$signer = New-BtRsa
$signer.FromXmlString([Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($keyFile), $null, 'CurrentUser')))
# La clé publique livrée (appli + lanceur) doit correspondre à la clé privée : sinon les postes refuseraient tout.
foreach ($f in $pubFiles) {
    $p = [regex]::Match([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8), "ReleasePublicKey\s*=\s*'([^']*)'").Groups[1].Value
    if ($p -ne $signer.ToXmlString($false)) { throw "La clé publique de $f ne correspond pas à la clé de signature." }
}

$cfg = Get-Content -LiteralPath (Join-Path $src 'config.ps1') -Raw -Encoding UTF8
$ver = [regex]::Match($cfg, "Version\s*=\s*'([^']+)'").Groups[1].Value
$gh  = [regex]::Match($cfg, "GitHubRepo\s*=\s*'([^']+)'").Groups[1].Value
$branch = [regex]::Match($cfg, "UpdateBranch\s*=\s*'([^']+)'").Groups[1].Value
if (-not $ver -or -not $gh) { throw 'Version ou GitHubRepo introuvable dans config.ps1.' }
if (-not $branch) { $branch = 'main' }
$name = "BiblioTech-Widget_version$ver"

# Notes de version.
$notes = @()
try {
    $rel = Get-Content -LiteralPath (Join-Path $src 'releases.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($rel.PSObject.Properties.Name -contains $ver) { $notes = @($rel.$ver | ForEach-Object { [string]$_ }) }
} catch { Write-Host "Avertissement : releases.json illisible ($($_.Exception.Message))" -ForegroundColor Yellow }
if (-not $notes.Count) { Write-Host "Avertissement : aucune note pour $ver dans releases.json." -ForegroundColor Yellow }

# Documents DSI (hors dépôt, ..\Biblio-Tech - Note DSI : Note DSI, fiche cybersécurité,
# dossier technique, fiche données et accès ; sauvegardes ignorées) : ils doivent
# décrire la version publiée. Simple avertissement en essai ; publication refusée sinon
# (-SkipDocCheck pour passer outre, ex. depuis un poste sans ces documents).
$docDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Biblio-Tech - Note DSI'
$docLate = @()
if (Test-Path -LiteralPath $docDir) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    foreach ($doc in Get-ChildItem -LiteralPath $docDir -Filter '*.docx' | Where-Object { $_.Name -notlike '~$*' -and $_.Name -notmatch '\(sauvegarde ' }) {
        $docVer = ''
        try {
            $fs = [IO.File]::Open($doc.FullName, 'Open', 'Read', 'ReadWrite')   # lisible même ouvert dans Word
            try {
                $zipDoc = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Read)
                $rd = New-Object IO.StreamReader($zipDoc.GetEntry('word/document.xml').Open(), [Text.Encoding]::UTF8)
                $plain = $rd.ReadToEnd() -replace '<[^>]+>', ''; $rd.Dispose(); $zipDoc.Dispose()
                $docVer = [regex]::Match($plain, '(?i)version\s+(?:de l.outil|analys[ée]e)\s*:\s*(\d+(?:\.\d+)+)').Groups[1].Value
            } finally { $fs.Dispose() }
        } catch { }
        if ($docVer -ne $ver) { $docLate += "$($doc.Name) (version indiquée : $(if ($docVer) { $docVer } else { 'introuvable' }))" }
    }
} else { Write-Host "Avertissement : dossier des documents DSI introuvable ($docDir), contrôle ignoré." -ForegroundColor Yellow }
if ($docLate.Count) {
    $docMsg = "Documents DSI / cybersécurité à mettre à jour pour la $ver :`n  " + ($docLate -join "`n  ")
    if ($NoPublish -or $SkipDocCheck) { Write-Host "Avertissement : $docMsg" -ForegroundColor Yellow }
    else { throw "$docMsg`n(revoir leur contenu, les mettre à jour via Word, ou relancer avec -SkipDocCheck)" }
}

# Validation syntaxique de tous les scripts avant de publier.
$bad = @()
Get-ChildItem -LiteralPath $repo -Recurse -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\(dist|Archives)\\' } | ForEach-Object {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errs)
    if ($errs) { $bad += "$($_.Name) : $($errs[0].Message) (ligne $($errs[0].Extent.StartLineNumber))" }
}
if ($bad.Count) { throw ("Erreurs de syntaxe :`n" + ($bad -join "`n")) }

# --- Zips ---
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }
$staging = Join-Path ([System.IO.Path]::GetTempPath()) $name
if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
# Contenu SIGNÉ = uniquement les fichiers suivis par Git (+ nouveaux fichiers non ignorés) de
# l'appli et du lanceur : jamais un fichier ignoré déposé dans le dossier (synchronisé) du projet.
# Le lanceur voyage avec chaque version : bootstrap.ps1 le recopie hors du dossier app.
Push-Location $repo
try {
    $files = @(& git -c core.quotepath=off ls-files --cached --others --exclude-standard -- 'BiblioTech-Widget-PS' 'launcher' | Where-Object { $_ })
    $fresh = @(& git -c core.quotepath=off ls-files --others --exclude-standard -- 'BiblioTech-Widget-PS' 'launcher' | Where-Object { $_ })
} finally { Pop-Location }
if (-not $files.Count) { throw 'Aucun fichier à empaqueter (git ls-files vide).' }
if ($fresh.Count) { Write-Host ("Fichiers NOUVEAUX inclus dans la version signée (à vérifier) :`n  " + ($fresh -join "`n  ")) -ForegroundColor Yellow }
foreach ($f in $files) {
    $rel = if ($f.StartsWith('BiblioTech-Widget-PS/')) { $f.Substring('BiblioTech-Widget-PS/'.Length) } else { $f }
    $dst = Join-Path $staging ($rel -replace '/', '\')
    $dd = Split-Path $dst -Parent
    if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $repo ($f -replace '/', '\')) -Destination $dst -Force
}
$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

# --- Biblio-Tech.cmd : FICHIER UNIQUE (installation / MAJ / réparation / lancement) ---
# En-tête batch (ASCII) qui relit le fichier et exécute le PowerShell placé après le
# marqueur = launcher\bootstrap.ps1 tel quel. UTF-8 SANS BOM (cmd ne lit pas le BOM),
# fins de ligne CRLF. Écrit à la racine du dépôt (lien stable) et copié dans dist\.
$cmdHeader = @'
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
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:BT_SELF,[Text.Encoding]::UTF8); $i=$s.IndexOf('#'+'#BIBLIOTECH-PS#'+'#'); & ([ScriptBlock]::Create($s.Substring($i))) %BTARGS%"
exit /b
##BIBLIOTECH-PS##
'@
$bsText = [IO.File]::ReadAllText((Join-Path $repo 'launcher\bootstrap.ps1'), [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
$cmdText = (($cmdHeader.TrimEnd() + "`n" + $bsText) -replace "`r`n", "`n") -replace "`n", "`r`n"
$oneCmd = Join-Path $repo 'Biblio-Tech.cmd'
[IO.File]::WriteAllText($oneCmd, $cmdText, (New-Object System.Text.UTF8Encoding $false))
$kit = Join-Path $dist 'Biblio-Tech.cmd'
Copy-Item -LiteralPath $oneCmd -Destination $kit -Force
# Le zip de version contient aussi le .cmd (à la racine, à côté du dossier de l'app) :
# chaque zip archivé reste un livrable complet, comme pour le SNOW Widget.
Compress-Archive -LiteralPath $oneCmd -DestinationPath $zip -Update
Remove-Item -LiteralPath (Join-Path $dist 'BiblioTech-Installer.zip') -Force -ErrorAction SilentlyContinue

$arch = Join-Path $repo 'Archives'
Get-ChildItem -LiteralPath $dist -Filter 'BiblioTech-Widget_version*.zip' | Where-Object { $_.Name -ne "$name.zip" } | ForEach-Object {
    if (-not (Test-Path $arch)) { New-Item -ItemType Directory -Path $arch -Force | Out-Null }
    Move-Item -LiteralPath $_.FullName -Destination $arch -Force
    Write-Host "Archivé : $($_.Name) -> Archives\"
}
$sha = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
Write-Host ("OK : {0}.zip ({1} Ko) sha256={2}" -f $name, [int]((Get-Item $zip).Length / 1KB), $sha) -ForegroundColor Green

# Signature « BiblioTech-Widget|<version>|<SHA-256> » (lie le zip à SA version : pas de rejeu
# d'un ancien zip légitime annoncé comme nouvelle version), vérifiée aussitôt.
$signed = [Text.Encoding]::UTF8.GetBytes("BiblioTech-Widget|$ver|$($sha.ToUpperInvariant())")
$sig = [Convert]::ToBase64String($signer.SignData($signed, 'SHA256'))
$check = New-BtRsa; $check.FromXmlString($signer.ToXmlString($false))
if (-not $check.VerifyData($signed, 'SHA256', [Convert]::FromBase64String($sig))) { throw 'Signature de la version invalide (contrôle interne).' }
Write-Host 'Version signée (clé locale).' -ForegroundColor Green

$manifest = [ordered]@{
    version = $ver
    zip     = "$name.zip"
    url     = "https://github.com/$gh/releases/download/v$ver/$name.zip"
    sha256  = $sha
    sig     = $sig
    date    = (Get-Date -Format 'yyyy-MM-dd')
    notes   = $notes
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
$utf8 = New-Object System.Text.UTF8Encoding $false

if ($NoPublish) {
    [System.IO.File]::WriteAllText((Join-Path $dist 'latest.preview.json'), $manifestJson, $utf8)
    Write-Host '-NoPublish : rien n''a été poussé (aperçu : dist\latest.preview.json).' -ForegroundColor Yellow
    return
}

# --- Publication (git ne doit pas écrire sur stderr sous 'Stop' : on lit $LASTEXITCODE) ---
$ErrorActionPreference = 'Continue'
Push-Location $repo
try {
    function Invoke-Git { & git @args 2>$null; if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') a échoué ($LASTEXITCODE)" } }
    $msgFile = Join-Path ([System.IO.Path]::GetTempPath()) ('btcommit_' + [guid]::NewGuid().ToString('N') + '.txt')
    $msg = "Version $ver"
    if ($notes.Count) { $msg += "`n`n" + (($notes | ForEach-Object { "- $_" }) -join "`n") }
    [System.IO.File]::WriteAllText($msgFile, $msg, $utf8)

    & git add -A 2>$null
    & git diff --cached --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { Invoke-Git commit -q -F $msgFile; Write-Host "Git : commit 'Version $ver'." }
    Invoke-Git push -q origin "HEAD:$branch"

    $notesFile = Join-Path ([System.IO.Path]::GetTempPath()) ('btnotes_' + [guid]::NewGuid().ToString('N') + '.md')
    $body = if ($notes.Count) { ($notes | ForEach-Object { "- $_" }) -join "`n" } else { "Version $ver" }
    $body += "`n`n**Installation, mise à jour ou réparation** : télécharger ``Biblio-Tech.cmd`` (fichier unique) et double-cliquer dessus.`nLes postes déjà équipés se mettent à jour seuls au lancement ou via la pastille de l'application."
    [System.IO.File]::WriteAllText($notesFile, $body, $utf8)
    # latest.json est AUSSI joint à la release : les postes le lisent via
    # github.com/<dépôt>/releases/latest/download/latest.json, disponible dès la publication
    # (raw.githubusercontent garde l'ancienne version ~5 min en cache).
    $relManifest = Join-Path $dist 'latest.json'
    [System.IO.File]::WriteAllText($relManifest, $manifestJson, $utf8)
    & gh release view "v$ver" --repo $gh 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & gh release upload "v$ver" $zip $kit $relManifest --clobber --repo $gh
        Write-Host "Release v$ver existante : assets remplacés."
    } else {
        & gh release create "v$ver" $zip $kit $relManifest --repo $gh --target $branch --title "Biblio-Tech Widget $ver" --notes-file $notesFile --latest
    }
    if ($LASTEXITCODE -ne 0) { throw 'Création de la release GitHub impossible.' }

    [System.IO.File]::WriteAllText((Join-Path $repo 'latest.json'), $manifestJson, $utf8)
    & git add latest.json 2>$null
    Invoke-Git commit -q -m "Publication $ver (latest.json)"
    Invoke-Git push -q origin "HEAD:$branch"
    Write-Host "Publié : https://github.com/$gh/releases/tag/v$ver" -ForegroundColor Green
    Write-Host 'Postes en 1.1.6+ : pastille sous ~2 min (latest.json de la release) ; versions antérieures : ~5 à 35 min.'
    Remove-Item $msgFile, $notesFile -Force -ErrorAction SilentlyContinue
} finally { Pop-Location }
