# ============================================================================
#  Couche WebView2 (moteur Edge/Chromium) : chargement des assemblies, création
#  des contrôles partageant le MÊME profil (cookies SSO communs), sondes JS
#  « kick -> poll ».
#
#  Principe (identique au SNOW Widget) : aucune API appelée depuis PowerShell,
#  aucun jeton manipulé. Le WebView2 est authentifié par le SSO de l'entreprise ;
#  les requêtes partent DE LA PAGE Confluence (fetch same-origin + cookie de
#  session). ExecuteScriptAsync ne résout pas les promesses : le JS dépose son
#  résultat dans une globale window.__btXxx que l'on sonde ensuite.
# ============================================================================

function Initialize-BtWebView2 {
    param([string]$LibDir)
    try {
        # Chargeur natif chargé par son CHEMIN COMPLET (et non SetDllDirectory, qui plaçait ce
        # dossier inscriptible AVANT System32 pour toutes les DLL du processus) : les appels
        # suivants « WebView2Loader.dll » réutilisent ce module déjà chargé.
        $loader = Join-Path $LibDir 'WebView2Loader.dll'
        if ([BtNative]::LoadLibraryW($loader) -eq [IntPtr]::Zero) { throw "WebView2Loader.dll non chargé ($loader)" }
        Add-Type -Path (Join-Path $LibDir 'Microsoft.Web.WebView2.Core.dll')
        Add-Type -Path (Join-Path $LibDir 'Microsoft.Web.WebView2.Wpf.dll')
        $v = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::GetAvailableBrowserVersionString()
        Write-BtLog "[WV2] Runtime WebView2 disponible : $v"
        return $true
    } catch {
        Write-BtLog "[WV2] WebView2 indisponible : $($_.Exception.Message)"
        return $false
    }
}

# Tous les WebView2 de l'app utilisent le même dossier de profil ET les mêmes
# arguments : ils partagent donc le même processus navigateur et la session SSO.
function New-BtWebView {
    param($Ctx)
    $wv = New-Object Microsoft.Web.WebView2.Wpf.WebView2
    $cp = New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
    $cp.UserDataFolder = (Join-Path $Ctx.DataDir 'webview2')
    $allow = $Ctx.Config.AuthAllowlist
    # SSO Windows intégré (Kerberos/Negotiate) vers les seuls serveurs de l'allowlist. PAS de
    # --auth-negotiate-delegate-allowlist : Confluence n'a pas besoin de la DÉLÉGATION des
    # identifiants (TGT transmissible), qui exposerait l'utilisateur à tout serveur *.sncf.fr.
    $cp.AdditionalBrowserArguments = "--auth-server-allowlist=$allow"
    $wv.CreationProperties = $cp
    # Fond affiché avant le chargement de la page : celui du thème Windows (pas de flash).
    $wv.DefaultBackgroundColor = if ($Ctx.Dark -ne $false) { [System.Drawing.Color]::FromArgb(255, 15, 23, 42) } else { [System.Drawing.Color]::White }
    return $wv
}

# Durcissement commun à chaque WebView2 (appelé à l'initialisation de son CoreWebView2) :
# - outils de développement (F12) désactivés (BT_DEVTOOLS=1 pour le développement) ;
# - aucune autorisation accordée aux pages (caméra, micro, position, notifications…) ;
# - aucun objet hôte exposé ; messages web réservés au tableau de bord (-WebMessages) ;
# - téléchargements : seulement depuis Confluence et seulement dans le lecteur (-Downloads).
function Set-BtWebHardening {
    param($Ctx, $Cw, [switch]$WebMessages, [switch]$Downloads)
    try {
        $st = $Cw.Settings
        $st.AreDevToolsEnabled = ($env:BT_DEVTOOLS -eq '1')
        $st.AreHostObjectsAllowed = $false
        $st.IsWebMessageEnabled = [bool]$WebMessages
        $Cw.add_PermissionRequested({ param($a, $b) $b.State = [Microsoft.Web.WebView2.Core.CoreWebView2PermissionState]::Deny })
        if ($Downloads) {
            $Cw.add_DownloadStarting({ param($a, $b)
                $h = ''; try { $h = ([uri]$b.DownloadOperation.Uri).Host } catch { }
                if ($h -ne $script:Ctx.ConfHost) { $b.Cancel = $true; Write-BtLog "[SECU] Téléchargement bloqué (hors Confluence) : $h" } })
        } else {
            $Cw.add_DownloadStarting({ param($a, $b) $b.Cancel = $true })
        }
    } catch { Write-BtLog "[SECU] Durcissement WebView2 incomplet : $($_.Exception.Message)" }
}

# Hôtes de confiance pour la NAVIGATION : Confluence et le fournisseur d'identité (IdP)
# appris lors de la connexion (State.IdpHost).
function Test-BtTrustedHost {
    param($Ctx, [string]$HostName)
    if (-not $HostName) { return $false }
    return ($HostName -eq $Ctx.ConfHost) -or ($Ctx.State.IdpHost -and $HostName -eq [string]$Ctx.State.IdpHost)
}

# Erreurs de navigation qui signifient « réseau / VPN indisponible ».
$script:BtNetErrors = @('HostNameNotResolved', 'CannotConnect', 'ServerUnreachable', 'Timeout',
    'ConnectionTimedOut', 'ConnectionAborted', 'ConnectionReset', 'Disconnected', 'ProxyAuthenticationRequired')

# --- Sonde générique kick -> poll ------------------------------------------
# -Raw : pour les GROS résultats (plusieurs Mo), le JSON n'est pas décodé ici (ConvertFrom-Json
# gèlerait la fenêtre) : seuls state / id sont lus en tête de texte, le texte brut (.raw) est
# décodé ensuite dans une tâche de fond. Le JS doit déposer {state:…, id:…, …} dans cet ordre.
function New-BtProbe {
    param([string]$Name, [switch]$Raw)
    return @{ Name = $Name; Phase = ''; Task = $null; PollJs = ''; ExpectId = ''; Deadline = (Get-Date); Raw = [bool]$Raw }
}

function Start-BtProbe {
    param($Ctx, $Probe, [string]$KickJs, [string]$PollJs, [int]$TimeoutSec, [string]$ExpectId = '')
    $Probe.PollJs = $PollJs
    $Probe.ExpectId = $ExpectId
    $Probe.Deadline = (Get-Date).AddSeconds($TimeoutSec)
    # Les sondes (recherche, identité…) ne s'exécutent QUE dans une page Confluence : si le
    # WebView est ailleurs (IdP, redirection), on ne lui confie ni requête ni résultat ->
    # réponse « AUTH » (reconnexion, la page Confluence est rechargée).
    $h = ''; try { $h = ([uri]$Ctx.WebView.CoreWebView2.Source).Host } catch { }
    if ($h -ne $Ctx.ConfHost) {
        $Probe.Fail = [pscustomobject]@{ state = 'AUTH'; id = $ExpectId; error = "page courante hors Confluence ($h)" }
        $Probe.Phase = 'fail'
        return
    }
    $Probe.Task = $Ctx.WebView.CoreWebView2.ExecuteScriptAsync($KickJs)
    $Probe.Phase = 'kick'
}

# Fait avancer la sonde d'un pas (appelée par la pompe). Renvoie $null tant que le
# résultat n'est pas prêt, sinon l'objet déposé par le JS (propriété .state).
function Step-BtProbe {
    param($Ctx, $Probe)
    if ($Probe.Phase -eq '') { return $null }
    if ($Probe.Phase -eq 'fail') { $Probe.Phase = ''; return $Probe.Fail }
    if (-not $Probe.Task.IsCompleted) {
        if ((Get-Date) -gt $Probe.Deadline.AddSeconds(10)) {
            $Probe.Phase = ''
            return [pscustomobject]@{ state = 'TIMEOUT'; error = 'délai dépassé (WebView2 ne répond pas)' }
        }
        return $null
    }
    if ($Probe.Phase -eq 'kick') {
        $Probe.Phase = 'poll'
        $Probe.Task = $Ctx.WebView.CoreWebView2.ExecuteScriptAsync($Probe.PollJs)
        return $null
    }
    $obj = $null
    try {
        $raw = $Probe.Task.Result
        if ($raw -and $raw -ne 'null') {
            if ($Probe.Raw) {
                $m = [regex]::Match($raw.Substring(0, [Math]::Min(300, $raw.Length)), '^\{"state":"(\w+)","id":"([^"]*)"')
                if ($m.Success) { $obj = [pscustomobject]@{ state = $m.Groups[1].Value; id = $m.Groups[2].Value; raw = $raw } }
            } else { $obj = $raw | ConvertFrom-Json }
        }
    } catch { }
    $ready = ($obj -and -not ($obj -is [string]) -and $obj.state -and $obj.state -ne 'PENDING')
    if ($ready -and $Probe.ExpectId -and ([string]$obj.id -ne $Probe.ExpectId)) { $ready = $false }
    if ($ready) { $Probe.Phase = ''; return $obj }
    if ((Get-Date) -gt $Probe.Deadline) {
        $Probe.Phase = ''
        return [pscustomobject]@{ state = 'TIMEOUT'; error = 'délai dépassé' }
    }
    $Probe.Task = $Ctx.WebView.CoreWebView2.ExecuteScriptAsync($Probe.PollJs)
    return $null
}

# --- Session SSO conservée d'un lancement à l'autre ------------------------------
# Le cookie de session Confluence et celui de l'IdP sont des cookies de SESSION (sans
# échéance) : WebView2 les efface à la fermeture -> validation SSO à CHAQUE lancement.
# Une fois connecté, on leur donne une échéance (Config.SessionKeepHours) dans le MÊME
# magasin de cookies du profil WebView2 (chiffré par Windows, comme celui d'un navigateur).
# L'appli ne lit ni ne copie aucune valeur. Le serveur reste maître : une session expirée
# côté Confluence / IdP redemande la validation comme avant. Toutes les 5 min, pour
# couvrir aussi les cookies renouvelés en cours de route. Tâches sondées par la pompe
# (attendre .Result sur le thread UI bloquerait WebView2).
function Step-BtKeepSession {
    param($Ctx)
    $k = $Ctx.Keep
    if ($Ctx.Demo -or [int]$Ctx.Config.SessionKeepHours -le 0) { return }
    if (-not $k.Task) {
        if (-not ($Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2)) { return }
        if ($k.NextAt -and (Get-Date) -lt $k.NextAt) { return }
        $k.NextAt = (Get-Date).AddMinutes(5)
        $k.Task = $Ctx.WebView.CoreWebView2.CookieManager.GetCookiesAsync('')
        return
    }
    if (-not $k.Task.IsCompleted) { return }
    $t = $k.Task; $k.Task = $null
    if ($t.IsFaulted) { Write-BtLog "[AUTH] Lecture des cookies impossible : $($t.Exception.InnerException.Message)"; return }
    $cm = $Ctx.WebView.CoreWebView2.CookieManager
    $until = (Get-Date).AddHours([int]$Ctx.Config.SessionKeepHours)
    # SEULS les cookies envoyés à Confluence ou à l'IdP appris (domaine exact ou domaine parent
    # de l'un d'eux) sont conservés : jamais ceux d'autres applications *.sncf.fr.
    $hosts = @($Ctx.ConfHost, [string]$Ctx.State.IdpHost) | Where-Object { $_ }
    $kept = @()
    foreach ($c in @($t.Result)) {
        if (-not $c.IsSession) { continue }
        $d = ([string]$c.Domain).TrimStart('.').ToLowerInvariant()
        if (-not $d -or -not @($hosts | Where-Object { $_ -eq $d -or $_.EndsWith('.' + $d) }).Count) { continue }
        try { $c.Expires = $until; $cm.AddOrUpdateCookie($c); $kept += "$($c.Name)@$d" }
        catch { Write-BtLog "[AUTH] Cookie $($c.Name)@$d non conservé : $($_.Exception.Message)" }
    }
    # Noms et domaines seulement (jamais de valeur) : utile pour le calibrage terrain.
    if ($kept.Count) { Write-BtLog ("[AUTH] Session conservée jusqu'au {0} : {1}" -f $until.ToString('dd/MM HH:mm'), ($kept -join ', ')) }
}


# --- Thème des pages : suit le thème Windows (clair / sombre) --------------------
# 1) Le profil WebView2 annonce le thème aux pages (prefers-color-scheme) : celles qui le
#    gèrent (tableau de bord, Confluence 9 en « thème du système ») suivent d'elles-mêmes.
# 2) Pages Confluence du LECTEUR en thème sombre : feuille de style injectée dès la création
#    du document (aucun flash blanc) qui inverse la page et redonne aux images leurs couleurs ;
#    retirée si la page est déjà sombre d'elle-même. Elle écoute le changement de thème :
#    basculer Windows en clair / sombre s'applique à la page ouverte, sans recharger.
$script:BtDarkPageJs = @'
(function(H){
  if (window.top !== window || location.hostname !== H || window.__btTheme) return;
  window.__btTheme = 1;
  var mq = window.matchMedia('(prefers-color-scheme: dark)'), el = null, native = false;
  var CSS = 'html{filter:invert(.9) hue-rotate(180deg)!important;background:#fff!important}'
    + 'img,video,picture,canvas,iframe,embed,object,svg image,[style*="background-image"]{filter:invert(1) hue-rotate(180deg)!important}';
  function nativeDark(){
    var de = document.documentElement;
    if (/dark/i.test(de.getAttribute('data-color-mode') || '') || /dark/i.test(de.getAttribute('data-theme') || '')) return true;
    var b = document.body; if (!b) return false;
    var m = (getComputedStyle(b).backgroundColor || '').match(/[0-9.]+/g);
    if (!m || m.length < 3 || (m.length > 3 && +m[3] === 0)) return false;
    return (0.299 * m[0] + 0.587 * m[1] + 0.114 * m[2]) < 110;
  }
  function apply(){
    var on = mq.matches && !native, root = document.head || document.documentElement;
    if (on && !el && root) { el = document.createElement('style'); el.id = 'bt-dark'; el.textContent = CSS; root.appendChild(el); }
    else if (!on && el) { if (el.parentNode) el.parentNode.removeChild(el); el = null; }
  }
  // Le script s'exécute AVANT que le document n'existe : style posé dès l'apparition de <html>.
  if (document.documentElement) apply();
  else new MutationObserver(function(m, o){ if (document.documentElement) { o.disconnect(); apply(); } }).observe(document, {childList:true});
  document.addEventListener('DOMContentLoaded', function(){ native = nativeDark(); apply(); });
  try { mq.addEventListener('change', apply); } catch (e) { mq.addListener(apply); }
})(__HOST__)
'@

# Thème des applications Windows (Paramètres > Personnalisation > Couleurs) : $true = sombre.
$script:BtStartedAt = Get-Date
function Test-BtSystemDark {
    # Tests : BT_THEME=light|dark force le thème ; BT_THEME_FLIP_SEC=n l'inverse après n s
    # (simule un changement de thème Windows pendant l'exécution).
    if ($env:BT_THEME) {
        $d = ($env:BT_THEME -ne 'light')
        if ($env:BT_THEME_FLIP_SEC -and ((Get-Date) - $script:BtStartedAt).TotalSeconds -ge [int]$env:BT_THEME_FLIP_SEC) { $d = -not $d }
        return $d
    }
    try {
        $v = [Microsoft.Win32.Registry]::GetValue('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme', $null)
        if ($null -eq $v) { return $true }
        return ([int]$v -eq 0)
    } catch { return $true }
}

# Applique le thème courant à un WebView (profil partagé : vaut pour toutes les pages).
function Set-BtWebTheme {
    param($Ctx, $Wv)
    if (-not $Wv) { return }
    try {
        $Wv.DefaultBackgroundColor = if ($Ctx.Dark) { [System.Drawing.Color]::FromArgb(255, 15, 23, 42) } else { [System.Drawing.Color]::White }
        if ($Wv.CoreWebView2) {
            $Wv.CoreWebView2.Profile.PreferredColorScheme = if ($Ctx.Dark) { [Microsoft.Web.WebView2.Core.CoreWebView2PreferredColorScheme]::Dark } else { [Microsoft.Web.WebView2.Core.CoreWebView2PreferredColorScheme]::Light }
        }
    } catch { Write-BtLog "[THEME] Application impossible : $($_.Exception.Message)" }
}

# Pages Confluence d'un WebView (lecteur) : mode sombre de secours, cf. $script:BtDarkPageJs.
function Register-BtDarkPages {
    param($Ctx, $Cw)
    try { [void]$Cw.AddScriptToExecuteOnDocumentCreatedAsync($script:BtDarkPageJs.Replace('__HOST__', ($Ctx.ConfHost | ConvertTo-Json -Compress))) }
    catch { Write-BtLog "[THEME] Script de thème non installé : $($_.Exception.Message)" }
}

# Pompe : relit le thème Windows toutes les 3 s et l'applique s'il a changé.
function Step-BtTheme {
    param($Ctx)
    if ($Ctx.ThemeAt -and (Get-Date) -lt $Ctx.ThemeAt) { return }
    $Ctx.ThemeAt = (Get-Date).AddSeconds(3)
    $d = Test-BtSystemDark
    if ($d -eq $Ctx.Dark -and $Ctx.ThemeApplied) { return }
    $Ctx.Dark = $d
    $Ctx.ThemeApplied = $true
    Write-BtLog ("[THEME] Thème Windows : {0}." -f $(if ($d) { 'sombre' } else { 'clair' }))
    # Interface WPF : nouvelle palette, ressources des fenêtres ouvertes, éléments redessinés.
    Set-BtPalette $d
    foreach ($w in @($Ctx.Window, $Ctx.Reader.Window, $Ctx.Dash.Window, $Ctx.AuthWindow)) { if ($w) { try { Set-BtThemeResources $w; Set-BtTitleBarTheme $w } catch { } } }
    try {
        Set-BtStatus $Ctx $Ctx.StatusKind $Ctx.StatusText
        Update-BtFooter $Ctx
        Render-BtFilters $Ctx
        Render-BtResults $Ctx
        if ($Ctx.Reader.Ui) { Update-BtReaderPin $Ctx; Update-BtReaderMode $Ctx }
    } catch { Write-BtLog "[THEME] Rafraîchissement de l'interface incomplet : $($_.Exception.Message)" }
    # Pages web (lecteur, tableau de bord) : même thème.
    foreach ($wv in @($Ctx.WebView, $Ctx.Reader.WebView, $Ctx.Dash.WebView)) { Set-BtWebTheme $Ctx $wv }
    try { if ($Ctx.Reader.Ui) { $Ctx.Reader.Ui.Host.Background = if ($d) { Get-BtBrush 'Panel' } else { [System.Windows.Media.Brushes]::White } } } catch { }
}
