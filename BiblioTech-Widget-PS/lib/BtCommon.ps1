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
# Cible : le .vbs de la COPIE LOCALE (pas de console). Aucun droit admin.
function Get-BtLauncherVbs {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'Start-BiblioTech.vbs')
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
