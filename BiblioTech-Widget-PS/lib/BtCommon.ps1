# ============================================================================
#  Utilitaires transverses : P/Invoke, dossier de données, journal, démarrage
#  automatique, ouverture d'URL.
# ============================================================================

if (-not ([System.Management.Automation.PSTypeName]'BtNative').Type) {
    Add-Type -Namespace '' -Name 'BtNative' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern bool SetDllDirectory(string lpPathName);
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
}

# Toutes les données d'exécution (état, journal, profil WebView2, copie locale de
# l'app) vivent dans %LOCALAPPDATA% : jamais dans un dossier synchronisé.
function Get-BtDataDir {
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = $env:APPDATA }
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    $dir = Join-Path $base 'BiblioTech-Widget'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Get-BtAppIconPath {
    param([string]$Ext = 'ico')
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($name in @("icone app.$Ext", "app.$Ext", "icon.$Ext")) {
        $p = Join-Path $root $name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

# --- Icône de la barre des tâches ---------------------------------------------
# Une fenêtre WPF hébergée par powershell.exe (WindowChrome, AppUserModelID explicite)
# ignore souvent Window.Icon dans la barre des tâches : bouton vide ou icône PowerShell.
# On pose l'icône au niveau Win32 (WM_SETICON) et on la ré-applique à plusieurs moments
# car la barre des tâches peut créer son bouton AVANT (même correctif que SNOW 1.5.17).
if (-not ([System.Management.Automation.PSTypeName]'BtIconNative').Type) {
    Add-Type -Namespace '' -Name 'BtIconNative' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr SendMessage(System.IntPtr hWnd, int Msg, System.IntPtr wParam, System.IntPtr lParam);
'@
}
$script:BtIconHandles = $null     # gardées vivantes pendant toute la session (HICON partagées)

function Set-BtWindowIconNative {
    param($Win)
    try {
        if (-not $script:BtIconHandles) {
            Add-Type -AssemblyName System.Drawing
            $ico = Get-BtAppIconPath 'ico'
            if ($ico) {
                $big = New-Object System.Drawing.Icon $ico, 32, 32
                $small = New-Object System.Drawing.Icon $ico, 16, 16
                $script:BtIconHandles = @{ Big = $big.Handle; Small = $small.Handle; Keep = @($big, $small) }
            } else {
                $png = Get-BtAppIconPath 'png'
                if (-not $png) { return }
                $src = New-Object System.Drawing.Bitmap $png
                $b32 = New-Object System.Drawing.Bitmap $src, (New-Object System.Drawing.Size 32, 32)
                $b16 = New-Object System.Drawing.Bitmap $src, (New-Object System.Drawing.Size 16, 16)
                $script:BtIconHandles = @{ Big = $b32.GetHicon(); Small = $b16.GetHicon(); Keep = @($src, $b32, $b16) }
            }
        }
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $Win).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        [void][BtIconNative]::SendMessage($hwnd, 0x0080, [IntPtr]1, $script:BtIconHandles.Big)    # WM_SETICON, ICON_BIG
        [void][BtIconNative]::SendMessage($hwnd, 0x0080, [IntPtr]0, $script:BtIconHandles.Small)  # ICON_SMALL
    } catch { Write-BtLog ("[UI] Icône barre des tâches : échec ({0})" -f $_.Exception.Message) }
}

# Branche la pose de l'icône sur une fenêtre : création du HWND, premier rendu, chaque
# réaffichage, et reprises différées (relance juste après une mise à jour).
function Register-BtWindowIcon {
    param($Win)
    $apply = { param($s, $e) Set-BtWindowIconNative $s }
    $Win.Add_SourceInitialized($apply)
    $Win.Add_ContentRendered($apply)
    $Win.Add_IsVisibleChanged({ param($s, $e) if ($s.IsVisible) { Set-BtWindowIconNative $s } })
    foreach ($ms in @(900, 2500, 6000)) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds($ms)
        $t.Tag = $Win
        $t.Add_Tick({ param($s, $e) $s.Stop(); Set-BtWindowIconNative $s.Tag })
        $t.Start()
    }
}

# --- Journal ----------------------------------------------------------------
$script:BtLogPath = $null

function Initialize-BtLog {
    param([string]$Path)
    $script:BtLogPath = $Path
    try {
        # On garde le journal précédent (utile après une mise à jour / un plantage).
        if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 2MB) {
            Move-Item -LiteralPath $Path -Destination ($Path + '.old') -Force
        }
        Add-Content -LiteralPath $Path -Value ("`r`n================ DEMARRAGE BIBLIO-TECH ({0}) ================" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
    } catch { }
}

function Write-BtLog {
    param([string]$Message)
    if (-not $script:BtLogPath) { return }
    try { Add-Content -LiteralPath $script:BtLogPath -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8 } catch { }
}

# --- URL / navigateur -------------------------------------------------------
function Test-BtHttpUrl {
    param([string]$Url)
    return ([string]$Url -match '^https?://')
}

# Ouvre une URL dans le navigateur par défaut (uniquement http/https).
function Open-BtExternal {
    param([string]$Url)
    if (-not (Test-BtHttpUrl $Url)) { return }
    try { Start-Process $Url } catch { Write-BtLog "[UI] Ouverture navigateur KO : $($_.Exception.Message)" }
}

# --- Raccourcis : démarrage automatique + menu Démarrer / Bureau ----------
# Cible : le lanceur %LOCALAPPDATA%\BiblioTech-Widget\launcher\Biblio-Tech.vbs (MAJ /
# réparation automatique au lancement), sinon le .vbs de la copie locale. Pas de console,
# aucun droit admin.
function Get-BtLauncherVbs {
    $lch = Join-Path (Get-BtDataDir) 'launcher\Biblio-Tech.vbs'
    if (Test-Path -LiteralPath $lch) { return $lch }
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'Start-BiblioTech.vbs')
}

# Copie installée : resynchronise le lanceur (livré dans app\launcher) et repointe les
# raccourcis existants vers lui — utile après une MAJ faite depuis la pastille.
function Sync-BtLauncher {
    param([string]$AppRoot)
    $src = Join-Path $AppRoot 'launcher'
    if (-not (Test-Path -LiteralPath (Join-Path $src 'bootstrap.ps1'))) { return }
    $dst = Join-Path (Get-BtDataDir) 'launcher'
    try {
        if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
        $changed = $false
        foreach ($f in @('bootstrap.ps1', 'Biblio-Tech.vbs')) {
            $s = Join-Path $src $f; $d = Join-Path $dst $f
            if (-not (Test-Path $s)) { continue }
            if (-not (Test-Path $d) -or (Get-FileHash $s).Hash -ne (Get-FileHash $d).Hash) { Copy-Item -LiteralPath $s -Destination $d -Force; $changed = $true }
        }
        if ($changed) { Write-BtLog '[INIT] Lanceur mis à jour.' }
        $vbs = Join-Path $dst 'Biblio-Tech.vbs'
        $wsh = New-Object -ComObject WScript.Shell
        foreach ($lnk in @((Join-Path ([Environment]::GetFolderPath('Programs')) 'Biblio-Tech Widget.lnk'),
                           (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Biblio-Tech Widget.lnk'),
                           (Get-BtStartupLnkPath))) {
            if (-not (Test-Path -LiteralPath $lnk)) { continue }
            if ($wsh.CreateShortcut($lnk).Arguments -notlike "*$vbs*") {
                New-BtShortcut $lnk 'Biblio-Tech - recherche dans la base de connaissances'
                Write-BtLog "[INIT] Raccourci repointé vers le lanceur : $lnk"
            }
        }
    } catch { Write-BtLog "[INIT] Synchronisation du lanceur : échec ($($_.Exception.Message))" }
}

function New-BtShortcut {
    param([string]$LnkPath, [string]$Description)
    $vbs = Get-BtLauncherVbs
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($LnkPath)
    $sc.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $sc.Arguments = '"' + $vbs + '"'
    $sc.WorkingDirectory = Split-Path $vbs -Parent
    $ico = Get-BtAppIconPath 'ico'
    if ($ico) { $sc.IconLocation = "$ico,0" } else { $sc.IconLocation = "$env:WINDIR\System32\imageres.dll,186" }
    $sc.Description = $Description
    $sc.Save()
}

function Get-BtStartupLnkPath { Join-Path ([Environment]::GetFolderPath('Startup')) 'Biblio-Tech Widget.lnk' }
function Test-BtAutoStartEnabled { Test-Path -LiteralPath (Get-BtStartupLnkPath) }

function Set-BtAutoStart {
    param([bool]$Enabled)
    $lnk = Get-BtStartupLnkPath
    try {
        if ($Enabled) { New-BtShortcut $lnk 'Biblio-Tech - recherche dans la base de connaissances'; Write-BtLog '[INIT] Démarrage auto activé.' }
        elseif (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force; Write-BtLog '[INIT] Démarrage auto désactivé.' }
    } catch { Write-BtLog "[INIT] Démarrage auto : échec ($($_.Exception.Message))" }
    return (Test-BtAutoStartEnabled)
}
