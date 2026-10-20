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

# Épinglage dans la barre des tâches : sans propriétés de relance, Windows épingle le
# PROCESSUS (powershell.exe : son icône, sa commande). On pose sur chaque fenêtre
# System.AppUserModel.RelaunchCommand / RelaunchDisplayNameResource / RelaunchIconResource
# puis System.AppUserModel.ID : l'épingle reprend l'icône du widget et relance le lanceur.
if (-not ([System.Management.Automation.PSTypeName]'BtTaskbar').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BtTaskbar {
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
    // PROPVARIANT : vt + pointeur (VT_LPWSTR) ; taille couverte pour x86 (16) et x64 (24).
    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; [FieldOffset(16)] public long pad; }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore {
        [PreserveSig] int GetCount(out uint c);
        [PreserveSig] int GetAt(uint i, out PROPERTYKEY k);
        [PreserveSig] int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
        [PreserveSig] int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
        [PreserveSig] int Commit();
    }
    [DllImport("shell32.dll")] static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore ps);
    [DllImport("ole32.dll")] static extern int PropVariantClear(ref PROPVARIANT pv);
    static readonly Guid FMT = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");   // System.AppUserModel.*
    static IPropertyStore Open(IntPtr hwnd) {
        Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"); IPropertyStore ps;
        int hr = SHGetPropertyStoreForWindow(hwnd, ref iid, out ps);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        return ps;
    }
    static void Set(IPropertyStore ps, uint pid, string val) {
        PROPERTYKEY k = new PROPERTYKEY(); k.fmtid = FMT; k.pid = pid;
        PROPVARIANT v = new PROPVARIANT(); v.vt = 31; v.p = Marshal.StringToCoTaskMemUni(val);   // VT_LPWSTR
        try { int hr = ps.SetValue(ref k, ref v); if (hr != 0) Marshal.ThrowExceptionForHR(hr); } finally { PropVariantClear(ref v); }
    }
    // pid : 2 RelaunchCommand, 3 RelaunchIconResource, 4 RelaunchDisplayNameResource, 5 ID (posé en dernier).
    public static void Apply(IntPtr hwnd, string appId, string command, string name, string icon) {
        IPropertyStore ps = Open(hwnd);
        try { Set(ps, 2, command); Set(ps, 4, name); Set(ps, 3, icon); Set(ps, 5, appId); ps.Commit(); }
        finally { Marshal.ReleaseComObject(ps); }
    }
    public static string Read(IntPtr hwnd, uint pid) {
        IPropertyStore ps = Open(hwnd);
        try {
            PROPERTYKEY k = new PROPERTYKEY(); k.fmtid = FMT; k.pid = pid; PROPVARIANT v;
            if (ps.GetValue(ref k, out v) != 0 || v.vt != 31) return null;
            try { return Marshal.PtrToStringUni(v.p); } finally { PropVariantClear(ref v); }
        } finally { Marshal.ReleaseComObject(ps); }
    }
}
'@
}
$script:BtAppId = 'SNCF.BiblioTechWidget'

function Set-BtWindowRelaunch {
    param($Win)
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $Win).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        $cmd = '"{0}" "{1}"' -f (Join-Path $env:WINDIR 'System32\wscript.exe'), (Get-BtLauncherVbs)
        $ico = Get-BtAppIconPath 'ico'
        [BtTaskbar]::Apply($hwnd, $script:BtAppId, $cmd, 'Biblio-Tech', $(if ($ico) { "$ico,0" } else { '' }))
    } catch { Write-BtLog ("[UI] Propriétés d'épinglage : échec ({0})" -f $_.Exception.Message) }
}

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
    $Win.Add_SourceInitialized({ param($s, $e) Set-BtWindowRelaunch $s })   # épinglage : icône + relance du widget
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

# AppendAllText plutôt qu'Add-Content : bien moins coûteux sur le thread de la fenêtre.
$script:BtLogEnc = New-Object System.Text.UTF8Encoding $true
function Write-BtLog {
    param([string]$Message)
    if (-not $script:BtLogPath) { return }
    try { [IO.File]::AppendAllText($script:BtLogPath, ("{0} {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $Message), $script:BtLogEnc) } catch { }
}

# --- Tâches de fond (runspace) -----------------------------------------------
# Les traitements lourds (gros JSON, index, rapports) tournent HORS du thread de la
# fenêtre, qui reste fluide. Le runspace reçoit une COPIE des fonctions nommées ; le
# script y est recréé à partir de son texte (un scriptblock passé tel quel s'exécuterait
# sur le runspace de la fenêtre). Write-BtLog y alimente un tampon, recopié dans le journal
# par le thread de la fenêtre à la réception (un seul thread écrit le journal).
# Ne JAMAIS créer de contrôle WPF dans une tâche de fond : données uniquement.
function Start-BtBgJob {
    param([string]$Name, [string[]]$Functions, [scriptblock]$Script, [object[]]$Arguments = @())
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    foreach ($f in $Functions) {
        $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($f, (Get-Item -LiteralPath "function:$f").Definition)))
    }
    $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry('Write-BtLog', 'param([string]$Message) [void]$global:BtBgLog.Add($Message)')))
    $rs = [runspacefactory]::CreateRunspace($iss)
    $rs.ApartmentState = [System.Threading.ApartmentState]::MTA
    $rs.Open()
    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($Body, $Arguments)
        $global:BtBgLog = New-Object System.Collections.Generic.List[string]
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try { $r = & ([scriptblock]::Create($Body)) @Arguments; $err = $null } catch { $r = $null; $err = $_.Exception.Message }
        return @{ Result = $r; Error = $err; Log = $global:BtBgLog.ToArray(); Ms = $sw.ElapsedMilliseconds }
    }.ToString()).AddArgument($Script.ToString()).AddArgument($Arguments)
    return @{ Name = $Name; PS = $ps; Runspace = $rs; Handle = $ps.BeginInvoke(); Started = (Get-Date) }
}

function Test-BtBgJobDone { param($Job) return [bool]($Job -and $Job.Handle.IsCompleted) }

# Résultat d'une tâche terminée : @{ Result; Error; Ms } (journal recopié au passage).
function Receive-BtBgJob {
    param($Job)
    $o = $null
    try {
        foreach ($x in $Job.PS.EndInvoke($Job.Handle)) { if ($x -is [hashtable]) { $o = $x } }   # (déjà déballé : .BaseObject serait lu comme une clé)
        if (-not $o) { $o = @{ Result = $null; Error = 'réponse vide'; Log = @(); Ms = 0 } }
    } catch { $o = @{ Result = $null; Error = $_.Exception.Message; Log = @(); Ms = 0 } }
    finally { try { $Job.PS.Dispose() } catch { }; try { $Job.Runspace.Dispose() } catch { } }
    foreach ($l in @($o.Log)) { Write-BtLog $l }
    if ($o.Error) { Write-BtLog "[FOND] $($Job.Name) : échec ($($o.Error))." }
    else { Write-BtLog ("[FOND] {0} terminé en {1} ms (hors fenêtre)." -f $Job.Name, $o.Ms) }
    return $o
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
