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
. (Join-Path $root 'lib\BtCategories.ps1')
. (Join-Path $root 'lib\BtDashboard.ps1')
. (Join-Path $root 'lib\BtBrowse.ps1')
. (Join-Path $root 'lib\BtHome.ps1')
. (Join-Path $root 'config.ps1')

try { [void][BtNative]::SetCurrentProcessExplicitAppUserModelID($script:BtAppId) } catch { }

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
    # Connexion : parcours SSO silencieux au démarrage (session IdP encore valide -> connecté
    # sans rien voir) ; s'il reste sur l'IdP, la fenêtre est montrée SUR CETTE PAGE, jamais
    # interrompue (couper une demande SAML en vol faisait échouer la 1re validation, cf. 1.1.5).
    InfoAt     = $null           # sonde d'identité différée (session en cours d'établissement)
    AuthRetries = 0
    Demo       = ($env:BT_DEMO -eq '1')
    Ready      = $false          # session Confluence validée
    AuthState  = 'init'          # init | login | offline | ok
    UserName   = ''
    SpaceName  = ''
    WebView    = $null
    AuthWindow = $null
    # Connexion interactive : lancée UNIQUEMENT par un clic de l'utilisateur (« Se connecter »).
    # Tant qu'elle est en cours, l'appli ne renavigue jamais seule (validation SSO manuelle).
    LoginInteractive = $false
    LoginNavDone     = $false    # tentative silencieuse via login.action déjà faite
    AuthPromptAt     = $null     # SSO silencieux bloqué sur l'IdP -> fenêtre présentée à cette heure
    Info       = (New-BtProbe 'info')
    InfoRequested = $false
    NextInfoAt = (Get-Date).AddMinutes($Config.SessionCheckMin)
    NetRetryAt = $null
    Search     = @{
        Probe = (New-BtProbe 'search'); Pending = $null; Active = $null
        Typed = ''; DebounceAt = $null; ShownQuery = ''; Fresh = $false; Analysis = $null; Relaxed = $false; TitleIds = @(); ShowN = 25
        Results = @(); Total = 0; More = $false; Error = $null; LastVia = ''; LastMs = 0
        Recent = @(); RecentError = $null
    }
    Update     = @{ Phase = ''; Job = $null; Manual = $false; Available = $null; Target = $null; NextCheck = (Get-Date).AddSeconds(10)
                    Source = 'release'; LastCheckAt = (Get-Date); ReleaseFailLogged = $false }
    Reader     = @{ Window = $null; WebView = $null; Ui = $null; Item = $null; Url = '' }
    # Index des catégories : réponse de plusieurs Mo -> sonde en mode brut + tâche de fond (Job).
    Categ      = @{ Probe = (New-BtProbe 'categ' -Raw); Job = $null; Loaded = $false; Id = ''; Manual = $false; Mode = ''; AutoAt = $null; StartedAt = $null; Index = $null; Tree = $null }
    # Accueil en tuiles (lib\BtHome.ps1) : Nav = pile des « pages suivantes » ouvertes depuis
    # les tuiles ; Kids = sous-pages des rubriques (id -> @{ Items; Error; At }).
    Home       = @{ Probe = (New-BtProbe 'home'); Id = ''; At = $null; Top = @(); Fresh = @(); News = @(); Rubrics = @(); Highlights = @(); Sections = @(); HomeTitle = ''; Error = $null
                    Nav = (New-Object System.Collections.ArrayList)
                    KidProbe = (New-BtProbe 'kids'); KidId = ''; KidWant = $null; Kids = @{} }
    Browse     = $false          # onglet « Catégories » (arborescence) affiché à la place de l'accueil
    BrowseOpen = @{}             # nœuds dépliés (chemin -> $true)
    Dash       = @{ Window = $null; WebView = $null }
    Keep       = @{ Task = $null; NextAt = $null }
    Dark       = (Test-BtSystemDark)  # thème Windows (pages du lecteur / tableau de bord), relu par Step-BtTheme
    ThemeAt    = $null
    ThemeApplied = $false   # session SSO conservée (Step-BtKeepSession)
    Ui         = $null
    Window     = $null
    StatusKind = 'idle'
    StatusText = 'Démarrage…'
    FlashText  = ''
    FlashUntil = $null
    Quitting   = $false
}
# Filtres de type et de tri retirés de l'interface : on neutralise un choix mémorisé
# auparavant (sinon il filtrerait les recherches sans être visible).
$script:Ctx.State.Type = 'all'
$script:Ctx.State.Sort = 'relevance'
if ($script:Ctx.State.Version -ne $Config.Version) {
    Write-BtLog "[VERSION] $($script:Ctx.State.Version) -> $($Config.Version)"
    $script:Ctx.State.Version = $Config.Version
    Save-BtState $script:Ctx.State
}

if (Test-BtInstalledCopy $script:Ctx) { Sync-BtLauncher $root }

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
    Set-BtWindowIconNative $w     # le bouton de barre des tâches vient d'être (re)créé
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
    $ico = New-BtImageSource (Get-BtAppIconPath 'png') 64
    if ($ico) { $w.Icon = $ico }
    Register-BtWindowIcon $w
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
    # Retour vers Confluence (fin de la validation SSO, réception SAML…) : la fenêtre de
    # connexion est masquée AVANT l'affichage de la page, pour ne jamais montrer le vrai site
    # Confluence à l'utilisateur. Simple déplacement hors écran : la navigation continue ; si
    # Confluence renvoie finalement vers une page de connexion, NavigationCompleted la remontre.
    $wv.add_NavigationStarting({ param($s, $e)
        $c = $script:Ctx
        $u = $null; try { $u = [uri]$e.Uri } catch { }
        if (-not $u -or $u.Host -ne $c.ConfHost -or $u.AbsolutePath -match '(?i)/(login|dologin|authenticate)\.action') { return }
        $w = $c.AuthWindow
        if ($w -and $w.Left -gt -4000) {
            Hide-BtAuthWindow
            Write-BtLog '[AUTH] Retour vers Confluence : fenêtre de connexion masquée.'
            if ($c.Window -and $c.Window.IsVisible) { try { $c.Window.Activate() | Out-Null } catch { } }
        }
    })
    $wv.add_NavigationCompleted({ param($s, $e)
        $c = $script:Ctx
        $u = $null; try { $u = $s.Source } catch { }
        $ok = $true; try { $ok = [bool]$e.IsSuccess } catch { }
        if (-not $ok) {
            $err = try { [string]$e.WebErrorStatus } catch { '?' }
            if ($err -in $script:BtNetErrors) {
                Write-BtLog "[RESEAU] Navigation échouée ($err) : nouvel essai dans 20 s."
                # Le nouvel essai est une vérification silencieuse (s'arrête si le SSO demande une validation).
                $c.LoginInteractive = $false
                $c.NetRetryAt = (Get-Date).AddSeconds(20)
                Set-BtAuthState $c 'offline'
                return
            }
        }
        # about:blank = arrêt volontaire (attente du clic « Se connecter ») : rien à faire.
        if (-not $u -or $u.Scheme -eq 'about') { return }
        $h = $u.Host
        Write-BtLog "[AUTH] Navigation terminée : $h$($u.AbsolutePath)"
        # Étape intermédiaire du SSO côté Confluence (réception SAML / OIDC) : on attend la page finale.
        if ($h -eq $c.ConfHost -and $u.AbsolutePath -match '(?i)/plugins/servlet/(saml|sso|oidc|oauth)') { return }
        $isLogin =($h -ne $c.ConfHost) -or ($u.AbsolutePath -match '(?i)/(login|dologin|authenticate)\.action')
        if ($isLogin) {
            # Page du fournisseur d'identité ou de connexion Confluence.
            if ($c.LoginInteractive) { Set-BtAuthState $c 'login'; Show-BtAuthWindow; return }
            # Tentative SILENCIEUSE : si la session SSO est encore valide, l'IdP renvoie seul vers
            # Confluence en quelques instants. Sinon (validation demandée), la fenêtre est
            # présentée SUR CETTE MÊME PAGE après AuthPromptSec (jamais interrompue ni rechargée).
            $c.AuthPromptAt = (Get-Date).AddSeconds([int]$c.Config.AuthPromptSec)
            return
        }
        # Page Confluence chargée : on valide la session (après une validation manuelle, on
        # laisse au cookie de session le temps d'être pris en compte).
        $c.AuthPromptAt = $null
        $c.AuthRetries = 0
        $c.InfoAt = if ($c.LoginInteractive) { (Get-Date).AddMilliseconds(1500) } else { $null }
        $c.InfoRequested = $true
    })
    $w.Add_Closing({ param($s, $e) if (-not $script:Ctx.Quitting) { $e.Cancel = $true; Hide-BtAuthWindow } })
    $w.Show()
    Start-BtSilentLogin $Ctx 'démarrage'
}

# Tentative de connexion SILENCIEUSE : parcours SSO normal dans la fenêtre cachée.
# Session SSO encore valide -> reconnexion automatique sans rien afficher ; sinon la
# fenêtre de connexion est présentée sur la page de l'IdP (cf. NavigationCompleted).
function Start-BtSilentLogin {
    param($Ctx, [string]$Why)
    $Ctx.LoginInteractive = $false
    $Ctx.LoginNavDone = $false
    $Ctx.AuthRetries = 0
    $Ctx.AuthPromptAt = $null
    Set-BtAuthState $Ctx 'init'
    Write-BtLog "[AUTH] Tentative de connexion silencieuse ($Why) -> $($Ctx.HomeUrl)"
    try { $Ctx.WebView.Source = [uri]$Ctx.HomeUrl } catch { }
}

# Bascule en connexion MANUELLE : la fenêtre est montrée sur la page en cours (aucun
# rechargement) et l'appli ne renavigue plus d'elle-même tant que la session n'est pas validée.
function Show-BtLoginPrompt {
    param($Ctx, [string]$Why)
    $Ctx.AuthPromptAt = $null
    $Ctx.LoginInteractive = $true
    $Ctx.AuthRetries = 0
    Set-BtAuthState $Ctx 'login'
    Write-BtLog "[AUTH] Validation manuelle nécessaire ($Why) : fenêtre de connexion affichée."
    Show-BtAuthWindow -Force
}

# Clic « Se connecter » / « Afficher la connexion » / menu « Se reconnecter ».
function Start-BtInteractiveLogin {
    param($Ctx)
    if (-not $Ctx.WebView) { return }
    # Déjà en cours : on remontre simplement la fenêtre, SANS recharger la page de validation.
    if ($Ctx.LoginInteractive) { Show-BtAuthWindow -Force; return }
    $u = $null; try { $u = $Ctx.WebView.Source } catch { }
    $onLogin = $u -and $u.Scheme -ne 'about' -and ($u.Host -ne $Ctx.ConfHost -or $u.AbsolutePath -match '(?i)/(login|dologin|authenticate)\.action')
    Write-BtLog '[AUTH] Connexion interactive demandée par l''utilisateur.'
    $Ctx.NetRetryAt = $null
    if ($onLogin) { Show-BtLoginPrompt $Ctx 'demande de l''utilisateur'; return }   # parcours SSO en cours : on ne l'interrompt pas
    $Ctx.LoginInteractive = $true
    $Ctx.AuthRetries = 0
    Set-BtAuthState $Ctx 'init'
    # Pas de Show ici : la fenêtre n'apparaît que sur la page de l'IdP (NavigationCompleted),
    # jamais sur une page Confluence ; session encore valide -> connexion sans rien afficher.
    try { $Ctx.WebView.Source = [uri]$Ctx.HomeUrl } catch { }
}

# Reconnexion automatique (réseau revenu, session expirée, WebView relancé) : une
# tentative silencieuse. Sans effet pendant une connexion manuelle en cours.
function Invoke-BtReconnect {
    param($Ctx, [switch]$ShowWindow)
    if ($ShowWindow) { Start-BtInteractiveLogin $Ctx; return }
    if ($Ctx.LoginInteractive) {
        Write-BtLog '[AUTH] Reconnexion automatique ignorée : connexion manuelle en cours.'
        return
    }
    $Ctx.Ready = $false
    Start-BtSilentLogin $Ctx 'reconnexion'
}

# Résultat de la sonde d'identité.
function Complete-BtInfo {
    param($Ctx, $R)
    if ($R.state -eq 'OK') {
        $first = -not $Ctx.Ready
        $Ctx.Ready = $true
        $Ctx.LoginInteractive = $false
        $Ctx.LoginNavDone = $false
        $Ctx.AuthPromptAt = $null
        $Ctx.UserName = [string]$R.fullName
        if ($R.space) { $Ctx.SpaceName = [string]$R.space; try { Render-BtFilters $Ctx } catch { } }
        Hide-BtAuthWindow
        Set-BtAuthState $Ctx 'ok'
        Write-BtLog "[AUTH] Session valide ($($R.user)) - espace : $($R.space)"
        if ($first) {
            # Index des catégories : mis à jour à CHAQUE ouverture (incrémental), 20 s après la connexion.
            $Ctx.Categ.AutoAt = (Get-Date).AddSeconds(20)
            Request-BtSearch $Ctx '' 0 'recent'
            if ($Ctx.Search.Typed -and -not $Ctx.Search.ShownQuery) { $Ctx.Search.DebounceAt = Get-Date }
        }
    } elseif ($R.state -eq 'AUTH') {
        $Ctx.Ready = $false
        if (-not $Ctx.LoginInteractive) {
            Set-BtAuthState $Ctx 'init'
            if (-not $Ctx.LoginNavDone) {
                # Confluence affiché en anonyme (pas de redirection SSO automatique) : UNE tentative
                # via la page de connexion (déclenche le SSO), toujours silencieuse.
                $Ctx.LoginNavDone = $true
                Write-BtLog '[AUTH] Session anonyme : tentative via la page de connexion.'
                try { $Ctx.WebView.Source = [uri]($Ctx.Config.BaseUrl.TrimEnd('/') + '/login.action?os_destination=' + [uri]::EscapeDataString($Ctx.Config.HomePath)) } catch { }
            } else {
                Show-BtLoginPrompt $Ctx 'session anonyme'
            }
        } elseif ($Ctx.AuthRetries -lt 3) {
            # Connexion manuelle : JAMAIS de renavigation (elle relançait un 2e parcours SSO).
            # La session peut mettre un instant à être reconnue : on revérifie simplement.
            $Ctx.AuthRetries++
            Write-BtLog "[AUTH] Session pas encore reconnue : nouvelle vérification dans 2 s ($($Ctx.AuthRetries)/3)."
            $Ctx.InfoAt = (Get-Date).AddSeconds(2)
            $Ctx.InfoRequested = $true
        } else {
            Write-BtLog '[AUTH] Session toujours anonyme : la fenêtre de connexion reste ouverte (aucune relance automatique).'
            Show-BtAuthWindow
        }
    } else {
        Write-BtLog "[AUTH] Vérification de session impossible ($($R.state) $($R.error)) : nouvel essai."
        $Ctx.NetRetryAt = (Get-Date).AddSeconds(20)
    }
}

function Step-BtInfo {
    param($Ctx)
    if ($Ctx.Info.Phase -eq '') {
        if ($Ctx.InfoAt -and (Get-Date) -lt $Ctx.InfoAt) { return }
        $due =$Ctx.InfoRequested -or ($Ctx.Ready -and (Get-Date) -ge $Ctx.NextInfoAt)
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
        if ($Start -eq 0) { $s.Results = @(); $s.Error = $null; $s.Fresh = $true; $s.More = $false; $s.LastVia = ''; $s.ShowN = 25 }
    } else { $s.RecentError = $null }
    $an = $null; $relax = $false; $tcql = ''
    if ($Kind -eq 'recent') { $cql = Get-BtCql $Ctx $null -Recent }
    else {
        # TOUTES les notions sont exigées (préféré par l'utilisateur à la recherche « au moins un
        # mot » du site, essayée puis écartée le 2026-10-20). Pagination (« Afficher plus ») : on
        # garde l'analyse et le niveau (strict / élargi) en cours.
        $relax = ($Start -gt 0 -and $s.Relaxed)
        if ($Start -eq 0) { $s.Analysis = Resolve-BtQuery $q; $s.Relaxed = $false }
        $an = $s.Analysis
        $cql = Get-BtCql $Ctx $an -Relaxed:$relax
        # 1re page : les fiches dont le titre réunit toutes les notions passent en tête.
        if ($Start -eq 0) { $tcql = @((Get-BtCql $Ctx $an -TitleOnly)); $s.TitleIds = @() }
    }
    $kw = if ($an -and $an.Keywords) { $an.Keywords } else { $q }
    $s.Pending = @{ Id = [guid]::NewGuid().ToString('N'); Query = $q; Keywords = $kw; Start = $Start; Kind = $Kind; Cql = $cql; TitleCql = $tcql; Relaxed = $relax }
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
        Start-BtProbe $Ctx $s.Probe (Get-BtSearchKickJS $Ctx $job.Id $job.Cql $job.Keywords $job.Start @($job.TitleCql)) 'window.__btSearch' ([int]$Ctx.Config.FetchTimeoutSec * 3 + 5) $job.Id
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
            # Consignes uniquement : une pièce jointe remontée par le repli DOM est écartée.
            $items = @($R.items | Where-Object { $_ -and [string]$_.type -ne 'attachment' })
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
                # Bloc « titre » : mémorisé en 1re page, puis retiré des pages suivantes (pas de doublon).
                if ($Job.Start -eq 0) {
                    $s.TitleIds = @($R.titleIds | Where-Object { $_ } | ForEach-Object { [string]$_ })
                    $pc = @($R.prioCounts | Where-Object { $null -ne $_ })
                    if ($pc.Count) { Write-BtLog ("[SEARCH] En tête : {0} fiche(s) avec toutes les notions dans le titre{1}." -f [int]$pc[0], $(if ($pc.Count -gt 1) { ", $([int]$pc[1]) dans le texte" } else { '' })) }
                } elseif (@($s.TitleIds).Count) {
                    $items = @($items | Where-Object { @($s.TitleIds) -notcontains [string]$_.id })
                }
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
    foreach ($step in @('Step-BtInfo', 'Step-BtSearch', 'Step-BtUpdate', 'Step-BtCategScan', 'Step-BtHome', 'Step-BtKeepSession', 'Step-BtTheme')) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try { & $step $c } catch { Write-BtLog "[PUMP] $step : $($_.Exception.Message)" }
        # Diagnostic : toute étape qui bloque la fenêtre plus de 250 ms est signalée.
        if ($sw.ElapsedMilliseconds -gt 250) { Write-BtLog "[LENT] $step a bloqué la fenêtre $($sw.ElapsedMilliseconds) ms." }
    }
    try {
        # Fin de frappe -> recherche.
        if ($c.Search.DebounceAt -and (Get-Date) -ge $c.Search.DebounceAt) {
            $c.Search.DebounceAt = $null
            Request-BtSearch $c $c.Search.Typed 0 'search'
        }
        # Réseau / VPN revenu ?
        if ($c.NetRetryAt -and (Get-Date) -ge $c.NetRetryAt) { $c.NetRetryAt = $null; Invoke-BtReconnect $c }
        # SSO silencieux resté sur une page de l'IdP : une validation est demandée -> fenêtre.
        if ($c.AuthPromptAt -and (Get-Date) -ge $c.AuthPromptAt -and -not $c.Ready) { Show-BtLoginPrompt $c 'le SSO demande une validation' }
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
    foreach ($w in @($Ctx.Reader.Window, $Ctx.Dash.Window, $Ctx.AuthWindow, $Ctx.Window)) { try { if ($w) { $w.Close() } } catch { } }
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
    # BT_TEST_BROWSE : ouvre l'onglet « Catégories » (index local existant), 1re catégorie dépliée.
    if ($env:BT_TEST_BROWSE) {
        $script:Ctx.Browse = $true
        $tr = Get-BtCategTree $script:Ctx
        if ($tr) { foreach ($k in @($tr.Kids.Values | Sort-Object { $_.Name } | Select-Object -First 1)) { $script:Ctx.BrowseOpen[$k.Path] = $true; foreach ($k2 in @($k.Kids.Values | Sort-Object { $_.Name } | Select-Object -First 1)) { $script:Ctx.BrowseOpen[$k2.Path] = $true } } }
        Render-BtFilters $script:Ctx; Render-BtResults $script:Ctx
    }
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
