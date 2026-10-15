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
#  Usage :  powershell -ExecutionPolicy Bypass -File build-release.ps1 [-NoPublish]
#  Prérequis : git + gh authentifié (gh auth login) avec droits sur le dépôt.
# ============================================================================
param([switch]$NoPublish)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$src  = Join-Path $repo 'BiblioTech-Widget-PS'
$dist = Join-Path $repo 'dist'

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
Copy-Item -LiteralPath $src -Destination $staging -Recurse
$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal
Remove-Item -LiteralPath $staging -Recurse -Force

$kit = Join-Path $dist 'BiblioTech-Installer.zip'
if (Test-Path $kit) { Remove-Item -LiteralPath $kit -Force }
$kitStage = Join-Path ([System.IO.Path]::GetTempPath()) 'Biblio-Tech Widget'
if (Test-Path $kitStage) { Remove-Item -LiteralPath $kitStage -Recurse -Force }
Copy-Item -LiteralPath (Join-Path $repo 'launcher') -Destination $kitStage -Recurse
Compress-Archive -Path $kitStage -DestinationPath $kit -CompressionLevel Optimal
Remove-Item -LiteralPath $kitStage -Recurse -Force

$arch = Join-Path $repo 'Archives'
Get-ChildItem -LiteralPath $dist -Filter 'BiblioTech-Widget_version*.zip' | Where-Object { $_.Name -ne "$name.zip" } | ForEach-Object {
    if (-not (Test-Path $arch)) { New-Item -ItemType Directory -Path $arch -Force | Out-Null }
    Move-Item -LiteralPath $_.FullName -Destination $arch -Force
    Write-Host "Archivé : $($_.Name) -> Archives\"
}
$sha = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
Write-Host ("OK : {0}.zip ({1} Ko) sha256={2}" -f $name, [int]((Get-Item $zip).Length / 1KB), $sha) -ForegroundColor Green

$manifest = [ordered]@{
    version = $ver
    zip     = "$name.zip"
    url     = "https://github.com/$gh/releases/download/v$ver/$name.zip"
    sha256  = $sha
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
    $body += "`n`n**Installation** : télécharger ``BiblioTech-Installer.zip``, l'extraire puis lancer ``Biblio-Tech.cmd``.`nLes postes déjà équipés reçoivent la mise à jour via la pastille de l'application."
    [System.IO.File]::WriteAllText($notesFile, $body, $utf8)
    & gh release view "v$ver" --repo $gh 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        & gh release upload "v$ver" $zip $kit --clobber --repo $gh
        Write-Host "Release v$ver existante : assets remplacés."
    } else {
        & gh release create "v$ver" $zip $kit --repo $gh --target $branch --title "Biblio-Tech Widget $ver" --notes-file $notesFile --latest
    }
    if ($LASTEXITCODE -ne 0) { throw 'Création de la release GitHub impossible.' }

    [System.IO.File]::WriteAllText((Join-Path $repo 'latest.json'), $manifestJson, $utf8)
    & git add latest.json 2>$null
    Invoke-Git commit -q -m "Publication $ver (latest.json)"
    Invoke-Git push -q origin "HEAD:$branch"
    Write-Host "Publié : https://github.com/$gh/releases/tag/v$ver" -ForegroundColor Green
    Write-Host 'Les postes verront la pastille sous ~5 min (cache raw.githubusercontent).'
    Remove-Item $msgFile, $notesFile -Force -ErrorAction SilentlyContinue
} finally { Pop-Location }
