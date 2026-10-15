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
