# ============================================================================
#  Construit le paquet de l'agent Microsoft 365 Copilot « Biblio-Tech ».
#  Sortie : copilot-agent\build\BiblioTech-Copilot-Agent.zip, prêt à être
#  importé par un admin M365 (centre d'admin Teams > Gérer les applications >
#  Charger une nouvelle application, ou Microsoft 365 Agents Toolkit).
#
#  -ConnectionId : identifiant du connecteur Copilot « Confluence On-premises »
#                  déployé par l'admin M365 (voir LISEZMOI-DSI.md, étape 2).
#  -Version      : version de l'application (à incrémenter à chaque republication).
#  Aucun secret : le paquet ne contient ni jeton ni identifiant.
# ============================================================================
param(
    [Parameter(Mandatory = $true)][string]$ConnectionId,
    [string]$Version = '1.0.0'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.IO.Compression.FileSystem

$here  = $PSScriptRoot
$src   = Join-Path $here 'appPackage'
$build = Join-Path $here 'build'
$stage = Join-Path $build 'appPackage'
$icon  = Join-Path $here '..\BiblioTech-Widget-PS\assets\images\icone-biblio-tech-512.png'

if ($ConnectionId -notmatch '^[A-Za-z0-9]{3,32}$') { throw "ConnectionId invalide : lettres et chiffres uniquement (3 à 32 caractères), tel qu'affiché dans le centre d'admin M365." }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version attendue au format X.Y.Z' }
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false

# --- Agent déclaratif : instructions intégrées + connecteur ---
$instr = [IO.File]::ReadAllText((Join-Path $src 'instructions.txt'), [Text.Encoding]::UTF8).Trim()
if ($instr.Length -gt 8000) { throw "instructions.txt dépasse 8 000 caractères ($($instr.Length))." }
$agent = [IO.File]::ReadAllText((Join-Path $src 'declarativeAgent.json'), [Text.Encoding]::UTF8)
# Échappement JSON des instructions via le sérialiseur (guillemets, retours à la ligne, accents).
$instrJson = (ConvertTo-Json $instr -Compress).Trim('"')
$agent = $agent.Replace('__INSTRUCTIONS__', $instrJson).Replace('__CONFLUENCE_CONNECTION_ID__', $ConnectionId)
$a = $agent | ConvertFrom-Json
if (@($a.conversation_starters).Count -gt 12) { throw 'Plus de 12 conversation_starters.' }
if ($a.name.Length -gt 100 -or $a.description.Length -gt 1000) { throw 'name (100) ou description (1000) trop long.' }
[IO.File]::WriteAllText((Join-Path $stage 'declarativeAgent.json'), $agent, $utf8)

# --- Manifeste de l'application ---
$man = [IO.File]::ReadAllText((Join-Path $src 'manifest.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$man.version = $Version
if ($man.description.short.Length -gt 80 -or $man.description.full.Length -gt 4000) { throw 'Description du manifeste trop longue.' }
[IO.File]::WriteAllText((Join-Path $stage 'manifest.json'), ($man | ConvertTo-Json -Depth 10), $utf8)

# --- Icônes : couleur 192 px, contour 32 px (blanc sur transparent) ---
$orig = [System.Drawing.Image]::FromFile((Resolve-Path $icon).Path)
function Save-Scaled([int]$Size, [string]$Path) {
    $b = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($orig, 0, 0, $Size, $Size); $g.Dispose()
    if ($Path) { $b.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png) }
    return $b
}
(Save-Scaled 192 (Join-Path $stage 'color.png')).Dispose()
# Contour : on ne garde que les zones claires (livre + monture de la loupe), en blanc pur.
$big = Save-Scaled 128 $null
$out = New-Object System.Drawing.Bitmap 128, 128, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt 128; $y++) { for ($x = 0; $x -lt 128; $x++) {
    $c = $big.GetPixel($x, $y)
    $lum = (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B)
    $alpha = [int][Math]::Max(0, [Math]::Min(255, ($lum - 150) * 2.5)) * $c.A / 255
    $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int]$alpha, 255, 255, 255))
} }
$big.Dispose()
$o32 = New-Object System.Drawing.Bitmap 32, 32, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($o32); $g.InterpolationMode = 'HighQualityBicubic'; $g.DrawImage($out, 0, 0, 32, 32); $g.Dispose()
$o32.Save((Join-Path $stage 'outline.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$o32.Dispose(); $out.Dispose(); $orig.Dispose()

# --- Zip (fichiers à la racine de l'archive) ---
$zip = Join-Path $build 'BiblioTech-Copilot-Agent.zip'
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
Write-Host "Paquet prêt : $zip" -ForegroundColor Green
Write-Host "  version $Version · connecteur '$ConnectionId' · instructions $($instr.Length)/8000 car."
