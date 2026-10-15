# ============================================================================
#  Biblio-Tech Widget - point d'entrée (PowerShell + WPF + WebView2).
#  Recherche par mots-clés dans la base de connaissances Confluence (Biblio-Tech)
#  via la session SSO en cours : WebView2 authentifié + requêtes same-origin
#  exécutées DANS la page (aucun jeton, aucun identifiant stocké, aucun .exe).
#  Lancement : Start-BiblioTech.cmd / .vbs   (BT_DEMO=1 : données fictives)
# ============================================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing, System.Xaml

. (Join-Path $root 'lib\BtCommon.ps1')
# Masque la console au plus tôt (lancement direct du .ps1).
try { $cw = [BtNative]::GetConsoleWindow(); if ($cw -ne [IntPtr]::Zero) { [void][BtNative]::ShowWindow($cw, 0) } } catch { }
. (Join-Path $root 'lib\BtState.ps1')
. (Join-Path $root 'lib\BtNet.ps1')
. (Join-Path $root 'lib\BtSearch.ps1')
. (Join-Path $root 'lib\BtAssist.ps1')
. (Join-Path $root 'lib\BtUi.ps1')
. (Join-Path $root 'lib\BtWindow.ps1')
. (Join-Path $root 'lib\BtReader.ps1')
. (Join-Path $root 'lib\BtUpdate.ps1')
. (Join-Path $root 'config.ps1')

try { [void][BtNative]::SetCurrentProcessExplicitAppUserModelID('SNCF.BiblioTechWidget') } catch { }

# --- Garde mono-instance ---
# Une 2e instance (raccourci relancé alors que l'appli est masquée dans la zone de
# notification) signale simplement à la 1re de réafficher sa fenêtre, puis s'arrête.
$createdNew = $false
$script:BtMutex = New-Object System.Threading.Mutex($true, 'Global\BiblioTechWidgetSingleton', [ref]$createdNew)
if (-not $createdNew) {
    $shown = $false
    try { $ev = [System.Threading.EventWaitHandle]::OpenExisting('Global\BiblioTechWidgetShow'); $shown = $ev.Set(); $ev.Dispose() } catch { }
    if (-not $shown) { [System.Windows.Forms.MessageBox]::Show('Biblio-Tech est déjà en cours d''exécution (raccourci : ' + $Config.Hotkey + ').', 'Biblio-Tech') | Out-Null }
    return
}
$script:BtShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Global\BiblioTechWidgetShow')

$dataDir = Get-BtDataDir
Initialize-BtLog (Join-Path $dataDir 'app_debug.log')
Write-BtLog "[INIT] Version $($Config.Version) - dossier de l'app : $root"
$script:BtWebView2Ok = Initialize-BtWebView2 (Join-Path $root 'lib\webview2')

# --- Contexte global partagé ---
$script:Ctx = @{
    Config     = $Config
    DataDir    = $dataDir
    AppRoot    = $root
    State      = (New-BtState (Join-Path $dataDir 'state.json'))
    ConfHost   = ([uri]$Config.BaseUrl).Host
    HomeUrl    = $Config.BaseUrl.TrimEnd('/') + $Config.HomePath
    Demo       = ($env:BT_DEMO -eq '1')
    Ready      = $false          # session Confluence validée
    AuthState  = 'init'          # init | login | offline | ok
    UserName   = ''
    SpaceName  = ''
    WebView    = $null
    AuthWindow = $null
    Info       = (New-BtProbe 'info')
    InfoRequested = $false
    NextInfoAt = (Get-Date).AddMinutes($Config.SessionCheckMin)
    NetRetryAt = $null
    Search     = @{
        Probe = (New-BtProbe 'search'); Pending = $null; Active = $null
        Typed = ''; DebounceAt = $null; ShownQuery = ''; Fresh = $false; Analysis = $null; Relaxed = $false
        Results = @(); Total = 0; More = $false; Error = $null; LastVia = ''; LastMs = 0
        Recent = @(); RecentError = $null
    }
    Update     = @{ Phase = ''; Job = $null; Manual = $false; Available = $null; Target = $null; NextCheck = (Get-Date).AddSeconds(10) }
    Reader     = @{ Window = $null; WebView = $null; Ui = $null; Item = $null; Url = '' }
    Ui         = $null
    Window     = $null
    StatusKind = 'idle'
    StatusText = 'Démarrage…'
    FlashText  = ''
    FlashUntil = $null
    Quitting   = $false
}
if ($script:Ctx.State.Version -ne $Config.Version) {
    Write-BtLog "[VERSION] $($script:Ctx.State.Version) -> $($Config.Version)"
    $script:Ctx.State.Version = $Config.Version
    Save-BtState $script:Ctx.State
}

# --- Application WPF ---
$script:App = New-Object System.Windows.Application
$script:App.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
# Filet de sécurité : une exception dans un gestionnaire d'événement est
# journalisée au lieu de fermer l'application.
$script:App.add_DispatcherUnhandledException({
    param($s, $e)
    try {
        $ex = $e.Exception
        Write-BtLog ("[ERREUR UI] {0} : {1}" -f $ex.GetType().Name, $ex.Message)
        if ($ex.InnerException) { Write-BtLog ("[ERREUR UI] interne : {0}" -f $ex.InnerException.Message) }
    } catch { }
    $e.Handled = $true
})

# ------------------------------------------------------------ Authentification
# Le WebView principal vit dans une fenêtre « Connexion » parquée HORS ÉCRAN :
# elle n'est présentée que si le SSO demande une interaction (identifiants, MFA).
function Show-BtAuthWindow {
    param([switch]$Force)
    $w = $script:Ctx.AuthWindow
    if (-not $w) { return }
    if ($w.Left -gt -4000 -and $w.IsVisible -and -not $Force) { return }
    $wa = [System.Windows.SystemParameters]::WorkArea
    $w.Left = $wa.Left + ($wa.Width - $w.Width) / 2
    $w.Top = $wa.Top + ($wa.Height - $w.Height) / 2
    $w.ShowInTaskbar = $true
    $w.Show(); $w.Activate() | Out-Null
    Write-BtLog '[AUTH] Fenêtre de connexion présentée.'
}

function Hide-BtAuthWindow {
    $w = $script:Ctx.AuthWindow
    if (-not $w) { return }
    $w.ShowInTaskbar = $false
    $w.Left = -5000; $w.Top = -5000
}

function Set-BtAuthState {
    param($Ctx, [string]$State)
    $Ctx.AuthState = $State
    switch ($State) {
        'login'   { $Ctx.Ready = $false; Set-BtStatus $Ctx 'warn' 'Connexion requise' }
        'offline' { $Ctx.Ready = $false; Set-BtStatus $Ctx 'error' 'Confluence injoignable' }
        'ok'      { Set-BtStatus $Ctx 'ok' $(if ($Ctx.UserName) { "Connecté · $($Ctx.UserName)" } else { 'Connecté' }) }
        default   { Set-BtStatus $Ctx 'busy' 'Connexion à Confluence…' }
    }
    Render-BtResults $Ctx
}

function Start-BtAuth {
    param($Ctx)
    if (-not $script:BtWebView2Ok) { Set-BtStatus $Ctx 'error' 'WebView2 absent'; return }
    $w = New-Object System.Windows.Window
    $w.Title = 'Biblio-Tech · Connexion à Confluence'
    $w.Width = 980; $w.Height = 740
    $w.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $w.Left = -5000; $w.Top = -5000
    $w.ShowInTaskbar = $false
    $wv = New-BtWebView $Ctx
    $w.Content = $wv
    $Ctx.AuthWindow = $w
    $Ctx.WebView = $wv

    $wv.add_CoreWebView2InitializationCompleted({ param($s, $e)
        if (-not $e.IsSuccess) { Write-BtLog "[WV2] Échec init : $($e.InitializationException.Message)"; Set-BtStatus $script:Ctx 'error' 'WebView2 en échec'; return }
        Write-BtLog '[WV2] CoreWebView2 initialisé.'
        $cw = $s.CoreWebView2
        $cw.add_NewWindowRequested({ param($a, $b) $b.Handled = $true })
        # Processus navigateur tué (veille prolongée) : on recharge, le profil garde la session.
        $cw.add_ProcessFailed({ param($a, $b)
            Write-BtLog "[WV2] ProcessFailed ($($b.ProcessFailedKind)) -> rechargement."
            $script:Ctx.Ready = $false
            $script:Ctx.NetRetryAt = (Get-Date).AddSeconds(3) })
    })
    $wv.add_NavigationCompleted({ param($s, $e)
        $c = $script:Ctx
        $u = $null; try { $u = $s.Source } catch { }
        $ok = $true; try { $ok = [bool]$e.IsSuccess } catch { }
        if (-not $ok) {
            $err = try { [string]$e.WebErrorStatus } catch { '?' }
            if ($err -in $script:BtNetErrors) {
                Write-BtLog "[RESEAU] Navigation échouée ($err) : nouvel essai dans 20 s."
                $c.NetRetryAt = (Get-Date).AddSeconds(20)
                Set-BtAuthState $c 'offline'
                return
            }
        }
        $h = if ($u) { $u.Host } else { '' }
        Write-BtLog "[AUTH] Navigation terminée : $h$(if ($u) { $u.AbsolutePath })"
        if ($h -ne $c.ConfHost) {
            # Page du fournisseur d'identité : si elle ne se valide pas seule, on la montre.
            Set-BtAuthState $c 'login'
            Show-BtAuthWindow
            return
        }
        if ($u.AbsolutePath -match '(?i)/(login|dologin|authenticate)\.action') {
            Set-BtAuthState $c 'login'
            Show-BtAuthWindow
            return
        }
        $c.InfoRequested = $true     # page Confluence chargée : on valide la session
    })
    $w.Add_Closing({ param($s, $e) if (-not $script:Ctx.Quitting) { $e.Cancel = $true; Hide-BtAuthWindow } })
    $w.Show()
    $wv.Source = [uri]$Ctx.HomeUrl
    Set-BtAuthState $Ctx 'init'
    Write-BtLog "[AUTH] WebView2 démarré -> $($Ctx.HomeUrl)"
}

function Invoke-BtReconnect {
    param($Ctx, [switch]$ShowWindow)
    $Ctx.Ready = $false
    Set-BtAuthState $Ctx 'init'
    try { $Ctx.WebView.Source = [uri]$Ctx.HomeUrl } catch { }
    if ($ShowWindow) { Show-BtAuthWindow -Force }
}

# Résultat de la sonde d'identité.
function Complete-BtInfo {
    param($Ctx, $R)
    if ($R.state -eq 'OK') {
        $first = -not $Ctx.Ready
        $Ctx.Ready = $true
        $Ctx.UserName = [string]$R.fullName
        if ($R.space) { $Ctx.SpaceName = [string]$R.space; try { Render-BtFilters $Ctx } catch { } }
        Hide-BtAuthWindow
        Set-BtAuthState $Ctx 'ok'
        Write-BtLog "[AUTH] Session valide ($($R.user)) - espace : $($R.space)"
        if ($first) {
            Request-BtSearch $Ctx '' 0 'recent'
            if ($Ctx.Search.Typed -and -not $Ctx.Search.ShownQuery) { $Ctx.Search.DebounceAt = Get-Date }
        }
    } elseif ($R.state -eq 'AUTH') {
        Write-BtLog '[AUTH] Session anonyme : redirection vers la connexion.'
        Set-BtAuthState $Ctx 'login'
        try { $Ctx.WebView.Source = [uri]($Ctx.Config.BaseUrl.TrimEnd('/') + '/login.action?os_destination=' + [uri]::EscapeDataString($Ctx.Config.HomePath)) } catch { }
        Show-BtAuthWindow
    } else {
        Write-BtLog "[AUTH] Vérification de session impossible ($($R.state) $($R.error)) : nouvel essai."
        $Ctx.NetRetryAt = (Get-Date).AddSeconds(20)
    }
}

function Step-BtInfo {
    param($Ctx)
    if ($Ctx.Info.Phase -eq '') {
        $due = $Ctx.InfoRequested -or ($Ctx.Ready -and (Get-Date) -ge $Ctx.NextInfoAt)
        if ($due -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2) {
            $Ctx.InfoRequested = $false
            $Ctx.NextInfoAt = (Get-Date).AddMinutes($Ctx.Config.SessionCheckMin)
            Start-BtProbe $Ctx $Ctx.Info (Get-BtInfoKickJS $Ctx) 'window.__btInfo' 20
        }
        return
    }
    $r = Step-BtProbe $Ctx $Ctx.Info
    if ($r) { Complete-BtInfo $Ctx $r }
}

# ------------------------------------------------------------------- Recherche
# Kind : 'search' (saisie) | 'recent' (accueil : mises à jour de l'espace).
function Request-BtSearch {
    param($Ctx, [string]$Query, [int]$Start = 0, [string]$Kind = 'search', [switch]$Force)
    $q = ([string]$Query).Trim()
    $s = $Ctx.Search
    if ($Kind -eq 'search') {
        if (-not $q) {
            $s.ShownQuery = ''; $s.Pending = $null; $s.Error = $null
            Render-BtResults $Ctx
            return
        }
        if (-not $Force -and $q.Length -lt [int]$Ctx.Config.MinQueryLength) { return }
        if (-not $Force -and $Start -eq 0 -and $q -eq $s.ShownQuery -and -not $s.Error) { return }
        $s.ShownQuery = $q
        if ($Start -eq 0) { $s.Results = @(); $s.Error = $null; $s.Fresh = $true; $s.More = $false; $s.LastVia = '' }
    } else { $s.RecentError = $null }
    $an = $null; $relax = $false
    if ($Kind -eq 'recent') { $cql = Get-BtCql $Ctx $null -Recent }
    else {
        # Pagination (« Afficher plus ») : on garde l'analyse et le niveau (strict / élargi) en cours.
        $relax = ($Start -gt 0 -and $s.Relaxed)
        if ($Start -eq 0) { $s.Analysis = Resolve-BtQuery $q; $s.Relaxed = $false }
        $an = $s.Analysis
        $cql = Get-BtCql $Ctx $an -Relaxed:$relax
    }
    $kw = if ($an -and $an.Keywords) { $an.Keywords } else { $q }
    $s.Pending = @{ Id = [guid]::NewGuid().ToString('N'); Query = $q; Keywords = $kw; Start = $Start; Kind = $Kind; Cql = $cql; Relaxed = $relax }
    if (-not $Ctx.Ready -and -not $Ctx.Demo) { Set-BtStatus $Ctx 'busy' 'En attente de la connexion…' }
    Render-BtResults $Ctx
}

function Step-BtSearch {
    param($Ctx)
    $s = $Ctx.Search
    if (-not $s.Active) {
        if (-not $s.Pending) { return }
        if (-not $Ctx.Demo -and -not ($Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2)) { return }
        $job = $s.Pending; $s.Pending = $null; $s.Active = $job
        Write-BtLog "[SEARCH] $($job.Kind) start=$($job.Start) CQL : $($job.Cql)"
        if ($Ctx.Demo) { Complete-BtSearch $Ctx $job (Get-BtDemoResult $job.Keywords $job.Start -Recent:($job.Kind -eq 'recent')); return }
        Start-BtProbe $Ctx $s.Probe (Get-BtSearchKickJS $Ctx $job.Id $job.Cql $job.Keywords $job.Start) 'window.__btSearch' ([int]$Ctx.Config.FetchTimeoutSec * 3 + 5) $job.Id
        return
    }
    $r = Step-BtProbe $Ctx $s.Probe
    if ($null -eq $r) { return }
    Complete-BtSearch $Ctx $s.Active $r
}

function Complete-BtSearch {
    param($Ctx, $Job, $R)
    $s = $Ctx.Search
    $s.Active = $null
    # Une recherche plus récente attend déjà : ce résultat est périmé.
    if ($s.Pending -and $Job.Kind -eq 'search' -and $s.Pending.Kind -eq 'search') { return }
    switch ([string]$R.state) {
        'OK' {
            $items = @($R.items | Where-Object { $_ })
            # Langage courant : aucune fiche ne réunit toutes les notions -> relance élargie.
            $an = $s.Analysis
            if ($Job.Kind -eq 'search' -and $Job.Start -eq 0 -and -not $Job.Relaxed -and -not $items.Count -and $an -and (@($an.Groups).Count + @($an.Phrases).Count) -ge 2) {
                Write-BtLog '[SEARCH] 0 résultat en strict : relance élargie (au moins une notion).'
                $s.Relaxed = $true
                $s.Pending = @{ Id = [guid]::NewGuid().ToString('N'); Query = $Job.Query; Keywords = $Job.Keywords; Start = 0; Kind = 'search'; Cql = (Get-BtCql $Ctx $an -Relaxed); Relaxed = $true }
                return
            }
            if ($Job.Kind -eq 'recent') {
                $s.Recent = @($items | Select-Object -First ([int]$Ctx.Config.RecentCount))
            } else {
                $s.Results = if ($Job.Start -gt 0) { @($s.Results) + $items } else { $items }
                $s.Total = [int]$R.total
                $s.More = [bool]$R.more
                $s.LastVia = [string]$R.via
                $s.LastMs = [int]$R.ms
                $s.Fresh = $false
            }
            $errs = @($R.errors | Where-Object { $_ })
            if ($errs.Count) { Write-BtLog "[SEARCH] Replis : $($errs -join ' | ')" }
            Write-BtLog ("[SEARCH] OK via {0} : {1} élément(s) / {2} en {3} ms" -f $R.via, $items.Count, $R.total, $R.ms)
            if ($Ctx.Demo) { Set-BtStatus $Ctx 'ok' 'Mode démonstration' } elseif ($Ctx.Ready) { Set-BtAuthState $Ctx 'ok' }
        }
        'AUTH' {
            Write-BtLog "[SEARCH] Session expirée ($($R.error)) : reconnexion, la recherche sera relancée."
            if (-not $s.Pending) { $s.Pending = $Job }
            Invoke-BtReconnect $Ctx
            return
        }
        default {
            $msg = if ($R.error) { [string]$R.error } else { 'erreur inconnue' }
            Write-BtLog "[SEARCH] Échec ($($R.state)) : $msg"
            $friendly = "Confluence n'a pas répondu correctement. Détail : $msg"
            if ($Job.Kind -eq 'recent') { $s.RecentError = $friendly } else { $s.Error = $friendly; $s.Fresh = $false }
        }
    }
    Render-BtResults $Ctx
}

# ------------------------------------------------------------- Pompe + arrêt
function Step-BtPump {
    $c = $script:Ctx
    if ($c.Quitting) { return }
    foreach ($step in @('Step-BtInfo', 'Step-BtSearch', 'Step-BtUpdate')) {
        try { & $step $c } catch { Write-BtLog "[PUMP] $step : $($_.Exception.Message)" }
    }
    try {
        # Fin de frappe -> recherche.
        if ($c.Search.DebounceAt -and (Get-Date) -ge $c.Search.DebounceAt) {
            $c.Search.DebounceAt = $null
            Request-BtSearch $c $c.Search.Typed 0 'search'
        }
        # Réseau / VPN revenu ?
        if ($c.NetRetryAt -and (Get-Date) -ge $c.NetRetryAt) { $c.NetRetryAt = $null; Invoke-BtReconnect $c }
        # Fin du message temporaire du pied de panneau.
        if ($c.FlashUntil -and (Get-Date) -ge $c.FlashUntil) { $c.FlashUntil = $null; Update-BtFooter $c }
        # Raccourci relancé alors que l'appli tourne déjà -> réafficher la fenêtre.
        if ($script:BtShowEvent -and $script:BtShowEvent.WaitOne(0)) { Write-BtLog '[UI] Relance détectée : affichage de la fenêtre.'; Show-BtSearch $c }
    } catch { Write-BtLog "[PUMP] $($_.Exception.Message)" }
}

function Stop-BtApp {
    param($Ctx)
    if ($Ctx.Quitting) { return }
    $Ctx.Quitting = $true
    Write-BtLog '[INIT] Arrêt de l''application.'
    try { $script:BtPump.Stop() } catch { }
    try { if ($script:BtShowEvent) { $script:BtShowEvent.Dispose() } } catch { }
    try { Save-BtState $Ctx.State } catch { }
    try { if ($Ctx.Hotkey) { $Ctx.Hotkey.Dispose() } } catch { }
    try { if ($Ctx.Tray) { $Ctx.Tray.Visible = $false; $Ctx.Tray.Dispose() } } catch { }
    try { if ($Ctx.Window -and $Ctx.Window.IsVisible) { Save-BtWindowBounds $Ctx } } catch { }
    foreach ($w in @($Ctx.Reader.Window, $Ctx.AuthWindow, $Ctx.Window)) { try { if ($w) { $w.Close() } } catch { } }
    try { $script:App.Shutdown() } catch { }
}

# ------------------------------------------------------------------ Démarrage
Show-BtMainWindow $script:Ctx
Initialize-BtTray $script:Ctx
Initialize-BtHotkey $script:Ctx
if ($script:Ctx.Demo) {
    $script:Ctx.Ready = $true
    Set-BtStatus $script:Ctx 'ok' 'Mode démonstration'
    Request-BtSearch $script:Ctx '' 0 'recent'
    # BT_TEST_QUERY : pré-remplit la recherche (test visuel).
    if ($env:BT_TEST_QUERY) { Show-BtSearch $script:Ctx; $script:Ctx.Ui.SearchBox.Text = $env:BT_TEST_QUERY }
} else {
    Start-BtAuth $script:Ctx
}

$script:BtPump = New-Object System.Windows.Threading.DispatcherTimer
$script:BtPump.Interval = [TimeSpan]::FromMilliseconds(200)
$script:BtPump.Add_Tick({ Step-BtPump })
$script:BtPump.Start()

# Arrêt automatique (tests) : BT_AUTOQUIT_SEC=n.
if ($env:BT_AUTOQUIT_SEC) {
    $script:BtQuitTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:BtQuitTimer.Interval = [TimeSpan]::FromSeconds([int]$env:BT_AUTOQUIT_SEC)
    $script:BtQuitTimer.Add_Tick({ $script:BtQuitTimer.Stop(); Stop-BtApp $script:Ctx })
    $script:BtQuitTimer.Start()
}

Write-BtLog '[INIT] Interface prête.'
[void]$script:App.Run()
try { $script:BtMutex.ReleaseMutex() } catch { }
