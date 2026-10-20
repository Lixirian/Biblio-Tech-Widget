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
        [BtNative]::SetDllDirectory($LibDir) | Out-Null
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
    $cp.AdditionalBrowserArguments = "--auth-server-allowlist=$allow --auth-negotiate-delegate-allowlist=$allow"
    $wv.CreationProperties = $cp
    $wv.DefaultBackgroundColor = [System.Drawing.Color]::FromArgb(255, 15, 23, 42)
    return $wv
}

# Erreurs de navigation qui signifient « réseau / VPN indisponible ».
$script:BtNetErrors = @('HostNameNotResolved', 'CannotConnect', 'ServerUnreachable', 'Timeout',
    'ConnectionTimedOut', 'ConnectionAborted', 'ConnectionReset', 'Disconnected', 'ProxyAuthenticationRequired')

# --- Sonde générique kick -> poll ------------------------------------------
function New-BtProbe {
    param([string]$Name)
    return @{ Name = $Name; Phase = ''; Task = $null; PollJs = ''; ExpectId = ''; Deadline = (Get-Date) }
}

function Start-BtProbe {
    param($Ctx, $Probe, [string]$KickJs, [string]$PollJs, [int]$TimeoutSec, [string]$ExpectId = '')
    $Probe.PollJs = $PollJs
    $Probe.ExpectId = $ExpectId
    $Probe.Deadline = (Get-Date).AddSeconds($TimeoutSec)
    $Probe.Task = $Ctx.WebView.CoreWebView2.ExecuteScriptAsync($KickJs)
    $Probe.Phase = 'kick'
}

# Fait avancer la sonde d'un pas (appelée par la pompe). Renvoie $null tant que le
# résultat n'est pas prêt, sinon l'objet déposé par le JS (propriété .state).
function Step-BtProbe {
    param($Ctx, $Probe)
    if ($Probe.Phase -eq '') { return $null }
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
    try { $raw = $Probe.Task.Result; if ($raw -and $raw -ne 'null') { $obj = $raw | ConvertFrom-Json } } catch { }
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
function Get-BtCookieDomainRx {
    param([string]$Allowlist)
    $rx = @(([string]$Allowlist -split '[,;\s]+') | Where-Object { $_ } | ForEach-Object {
        if ($_.StartsWith('*.')) { '(^|\.)' + [regex]::Escape($_.Substring(2)) + '$' } else { '^' + [regex]::Escape($_) + '$' } })
    return ($rx -join '|')
}

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
    $rx = Get-BtCookieDomainRx $Ctx.Config.AuthAllowlist
    $until = (Get-Date).AddHours([int]$Ctx.Config.SessionKeepHours)
    $kept = @()
    foreach ($c in @($t.Result)) {
        if (-not $c.IsSession) { continue }
        $d = ([string]$c.Domain).TrimStart('.')
        if (-not $rx -or $d -notmatch $rx) { continue }
        try { $c.Expires = $until; $cm.AddOrUpdateCookie($c); $kept += "$($c.Name)@$d" }
        catch { Write-BtLog "[AUTH] Cookie $($c.Name)@$d non conservé : $($_.Exception.Message)" }
    }
    # Noms et domaines seulement (jamais de valeur) : utile pour le calibrage terrain.
    if ($kept.Count) { Write-BtLog ("[AUTH] Session conservée jusqu'au {0} : {1}" -f $until.ToString('dd/MM HH:mm'), ($kept -join ', ')) }
}
