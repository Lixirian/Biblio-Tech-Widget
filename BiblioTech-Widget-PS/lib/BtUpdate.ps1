# ============================================================================
#  Mise à jour automatique depuis GitHub (dépôt PUBLIC : lecture anonyme, aucun
#  jeton). Même parcours que le SNOW Widget :
#    1. contrôle périodique de latest.json (raw.githubusercontent.com) ;
#    2. version plus récente -> pastille « Mise à jour » dans la barre ;
#    3. clic -> notes de version -> confirmation -> téléchargement du zip (asset de
#       la release), vérification SHA-256, puis updater DÉTACHÉ qui attend la
#       fermeture de l'app, remplace la copie locale et relance.
#  Les requêtes réseau tournent dans un runspace : l'interface ne gèle jamais.
#
#  latest.json : { version, zip, url, sha256, date, notes[] }
# ============================================================================

# Téléchargement (texte ou fichier) via le proxy système + identifiants Windows
# (pour le proxy uniquement). Exécuté dans un runspace séparé.
$script:BtWebJobScript = {
    param([string]$Url, [string]$OutFile)
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers['User-Agent'] = 'BiblioTech-Widget'
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $wc.Proxy = $proxy
        if ($OutFile) { $wc.DownloadFile($Url, $OutFile); return @{ Ok = $true; File = $OutFile } }
        $wc.Encoding = [System.Text.Encoding]::UTF8
        return @{ Ok = $true; Text = $wc.DownloadString($Url) }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Start-BtWebJob {
    param([string]$Url, [string]$OutFile = '')
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($script:BtWebJobScript.ToString()).AddArgument($Url).AddArgument($OutFile)
    return @{ PS = $ps; Handle = $ps.BeginInvoke(); Started = (Get-Date) }
}

function Receive-BtWebJob {
    param($Job)
    try {
        $out = $Job.PS.EndInvoke($Job.Handle)
        foreach ($o in $out) { if ($o -is [hashtable]) { return $o } }
        return @{ Ok = $false; Error = 'réponse vide' }
    } catch { return @{ Ok = $false; Error = $_.Exception.Message } }
    finally { try { $Job.PS.Dispose() } catch { } }
}

# Source 'release' (par défaut) : latest.json joint à la dernière release GitHub, disponible
# DÈS la publication. Source 'raw' (repli) : fichier du dépôt via raw.githubusercontent, dont
# le CDN garde l'ancienne version ~5 min (le paramètre anti-cache n'y change rien).
function Get-BtManifestUrl {
    param($Ctx, [string]$Source = 'release')
    $c = $Ctx.Config
    if ($Source -eq 'release') { return ('https://github.com/{0}/releases/latest/download/latest.json?t={1}' -f $c.GitHubRepo, [DateTime]::UtcNow.Ticks) }
    return ('https://raw.githubusercontent.com/{0}/{1}/latest.json?t={2}' -f $c.GitHubRepo, $c.UpdateBranch, [DateTime]::UtcNow.Ticks)
}

# Compare deux versions « x.y.z » numériquement (1.0.10 > 1.0.2). -1 / 0 / 1.
function Compare-BtVersion {
    param([string]$A, [string]$B)
    $pa = @(([string]$A -split '\.') | ForEach-Object { [int]('0' + ($_ -replace '\D', '')) })
    $pb = @(([string]$B -split '\.') | ForEach-Object { [int]('0' + ($_ -replace '\D', '')) })
    for ($i = 0; $i -lt [Math]::Max($pa.Count, $pb.Count); $i++) {
        $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($x -ne $y) { return $(if ($x -gt $y) { 1 } else { -1 }) }
    }
    return 0
}

# La mise à jour remplace les fichiers de l'app : uniquement autorisée pour la
# COPIE LOCALE installée par le lanceur (jamais sur un dossier de développement).
function Test-BtInstalledCopy {
    param($Ctx)
    $inst = [System.IO.Path]::GetFullPath((Join-Path $Ctx.DataDir 'app')).TrimEnd('\')
    $root = [System.IO.Path]::GetFullPath($Ctx.AppRoot).TrimEnd('\')
    return ($root -ieq $inst)
}

# Lance un contrôle (non bloquant). -Manual : retour visible à l'utilisateur.
function Invoke-BtUpdateCheck {
    param($Ctx, [switch]$Manual, [string]$Source = 'release')
    $u = $Ctx.Update
    if ($u.Phase) { return }
    if (-not $Ctx.Config.GitHubRepo) { return }
    $u.Manual = [bool]$Manual
    $u.Source = $Source
    $u.LastCheckAt = Get-Date
    $u.Job = Start-BtWebJob (Get-BtManifestUrl $Ctx $Source)
    $u.Phase = 'check'
    if ($Manual) { Show-BtFlash $Ctx 'Recherche de mise à jour…' }
}

# Machine d'état (appelée par la pompe).
function Step-BtUpdate {
    param($Ctx)
    $u = $Ctx.Update
    if (-not $u.Phase) {
        if ((Get-Date) -ge $u.NextCheck) {
            $u.NextCheck = (Get-Date).AddSeconds([Math]::Max(60, [int]$Ctx.Config.UpdateCheckIntervalSec))
            Invoke-BtUpdateCheck $Ctx
        }
        return
    }
    $timeout = if ($u.Phase -eq 'download') { 300 } else { 45 }
    if (-not $u.Job.Handle.IsCompleted) {
        if (((Get-Date) - $u.Job.Started).TotalSeconds -gt $timeout) {
            try { $u.Job.PS.Stop(); $u.Job.PS.Dispose() } catch { }
            Write-BtLog "[MAJ] Délai dépassé ($($u.Phase))."
            if ($u.Manual -or $u.Phase -eq 'download') { Show-BtFlash $Ctx 'Mise à jour : GitHub ne répond pas (réseau / proxy ?).' }
            $u.Phase = ''
        }
        return
    }
    $phase = $u.Phase
    $u.Phase = ''
    $r = Receive-BtWebJob $u.Job
    if ($phase -eq 'check') { Complete-BtUpdateCheck $Ctx $r }
    elseif ($phase -eq 'download') { Complete-BtUpdateDownload $Ctx $r }
}

function Complete-BtUpdateCheck {
    param($Ctx, $R)
    $u = $Ctx.Update
    if (-not $R.Ok -and $u.Source -eq 'release') {
        # Release sans latest.json joint (versions publiées avant 1.1.6) ou github.com filtré : repli.
        if (-not $u.ReleaseFailLogged) { Write-BtLog "[MAJ] latest.json de la release illisible ($($R.Error)) : repli sur le dépôt."; $u.ReleaseFailLogged = $true }
        Invoke-BtUpdateCheck $Ctx -Manual:$u.Manual -Source raw
        return
    }
    if (-not $R.Ok) {
        Write-BtLog "[MAJ] Lecture de latest.json KO : $($R.Error)"
        if ($u.Manual) { Show-BtFlash $Ctx 'Impossible de joindre GitHub pour vérifier les mises à jour.' }
        return
    }
    try {
        $j = ([string]$R.Text).TrimStart([char]0xFEFF) | ConvertFrom-Json
        $m = @{
            Version = [string]$j.version; Zip = [string]$j.zip; Url = [string]$j.url
            Sha256 = ([string]$j.sha256).ToUpperInvariant(); Sig = [string]$j.sig; Date = [string]$j.date
            Notes = @($j.notes | ForEach-Object { [string]$_ } | Where-Object { $_ })
        }
        if (-not $m.Url -and $m.Zip) { $m.Url = 'https://github.com/{0}/releases/download/v{1}/{2}' -f $Ctx.Config.GitHubRepo, $m.Version, $m.Zip }
    } catch { Write-BtLog "[MAJ] latest.json invalide : $($_.Exception.Message)"; return }

    if ($m.Version -and $m.Url -and (Compare-BtVersion $m.Version $Ctx.Config.Version) -gt 0) {
        if (-not $u.Available -or $u.Available.Version -ne $m.Version) {
            Write-BtLog "[MAJ] Nouvelle version disponible : $($m.Version) (actuelle $($Ctx.Config.Version), source $($u.Source))."
            # Fenêtre peut-être cachée dans la zone de notification : on prévient aussi par une bulle.
            if (-not $u.Manual) {
                try { $Ctx.Tray.ShowBalloonTip(8000, 'Biblio-Tech', "Mise à jour $($m.Version) disponible : cliquez sur la pastille « Mise à jour » de la fenêtre.", [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
            }
        }
        $u.Available = $m
        if ($u.Manual) { Invoke-BtPromptAndUpdate $Ctx -SkipCheck }
    } else {
        $u.Available = $null
        if ($u.Manual) { Show-BtFlash $Ctx "Vous utilisez la dernière version (v$($Ctx.Config.Version))." }
    }
    Update-BtUpdateBadge $Ctx
}

function Update-BtUpdateBadge {
    param($Ctx)
    $ui = $Ctx.Ui
    if (-not $ui -or -not $ui.UpdateBtn) { return }
    $a = $Ctx.Update.Available
    if ($a) {
        $ui.UpdateBtn.Content = ([string][char]0x2B06) + " Mise à jour $($a.Version)"
        $ui.UpdateBtn.Visibility = [System.Windows.Visibility]::Visible
    } else { $ui.UpdateBtn.Visibility = [System.Windows.Visibility]::Collapsed }
}

# Fenêtre des notes de version. Renvoie $true si l'utilisateur confirme.
function Show-BtUpdateDialog {
    param($Ctx, $M)
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False"
        WindowStartupLocation="CenterScreen" SizeToContent="Height" Width="480" FontFamily="Segoe UI">
  <Border Background="#0F172A" BorderBrush="#0088CE" BorderThickness="1" CornerRadius="14" Padding="22" Margin="12">
    <Border.Effect><DropShadowEffect BlurRadius="24" ShadowDepth="3" Opacity="0.5"/></Border.Effect>
    <StackPanel>
      <StackPanel Orientation="Horizontal">
        <Border Width="34" Height="34" CornerRadius="9" Background="#FFD166">
          <TextBlock Text="&#xE896;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16" Foreground="#0B1220" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="Mise à jour disponible" FontSize="17" FontWeight="Bold" Foreground="#E6EDF7"/>
          <TextBlock x:Name="VerText" FontSize="12" Foreground="#4FB3FF" FontWeight="SemiBold"/>
        </StackPanel>
      </StackPanel>
      <TextBlock Text="NOUVEAUTÉS" FontSize="10.5" FontWeight="Bold" Foreground="#8193B2" Margin="0,18,0,8"/>
      <Border Background="#152038" CornerRadius="10" Padding="14,10">
        <ScrollViewer MaxHeight="260" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Notes"/></ScrollViewer>
      </Border>
      <TextBlock Text="L'application va se fermer, se mettre à jour puis redémarrer automatiquement." FontSize="11.5" Foreground="#8193B2" TextWrapping="Wrap" Margin="0,12,0,0"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
        <Button x:Name="LaterBtn" Content="Plus tard" Padding="16,7" Margin="0,0,8,0" Foreground="#B8C4D8" Background="#1B2947" BorderThickness="0" Cursor="Hand"/>
        <Button x:Name="OkBtn" Content="Mettre à jour et redémarrer" Padding="16,7" Foreground="White" Background="#0088CE" BorderThickness="0" FontWeight="SemiBold" Cursor="Hand"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@
    $w = [System.Windows.Markup.XamlReader]::Parse($xaml)
    $w.FindName('VerText').Text = "Version $($Ctx.Config.Version)  →  $($M.Version)" + $(if ($M.Date) { "   ·   $($M.Date)" } else { '' })
    $notes = $w.FindName('Notes')
    $list = if (@($M.Notes).Count) { @($M.Notes) } else { @('Améliorations et corrections.') }
    foreach ($n in $list) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-BtThickness 0 3 0 3
        $dot = New-BtText -Text '•' -Size 13 -Color 'Accent'
        $dot.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
        $dot.Margin = New-BtThickness 0 0 8 0
        [void]$row.Children.Add($dot)
        [void]$row.Children.Add((New-BtText -Text $n -Size 12.5 -Color 'Body' -Wrap))
        [void]$notes.Children.Add($row)
    }
    $res = @{ Ok = $false }
    $w.Tag = $res
    $w.FindName('LaterBtn').Add_Click({ param($s, $e) [System.Windows.Window]::GetWindow($s).Close() })
    $w.FindName('OkBtn').Add_Click({ param($s, $e) $win = [System.Windows.Window]::GetWindow($s); $win.Tag.Ok = $true; $win.Close() })
    $w.Add_MouseLeftButtonDown({ param($s, $e) try { $s.DragMove() } catch { } })
    [void]$w.ShowDialog()
    return [bool]$res.Ok
}

function Invoke-BtPromptAndUpdate {
    param($Ctx, [switch]$SkipCheck)
    $m = $Ctx.Update.Available
    if (-not $m) { if (-not $SkipCheck) { Invoke-BtUpdateCheck $Ctx -Manual }; return }
    if (-not (Show-BtUpdateDialog $Ctx $m)) { return }
    if (-not (Test-BtInstalledCopy $Ctx)) {
        Show-BtFlash $Ctx 'Copie de développement : mettez à jour via git (mise à jour auto réservée à la copie installée).'
        Write-BtLog "[MAJ] Refusée : $($Ctx.AppRoot) n'est pas la copie installée."
        return
    }
    $dir = Join-Path $Ctx.DataDir 'update'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $zip = Join-Path $dir ("BiblioTech-Widget_version{0}.zip" -f ($m.Version -replace '[^0-9.]', ''))
    $Ctx.Update.Target = @{ Manifest = $m; Zip = $zip }
    $Ctx.Update.Job = Start-BtWebJob $m.Url $zip
    $Ctx.Update.Phase = 'download'
    Show-BtFlash $Ctx "Téléchargement de la version $($m.Version)…"
    Write-BtLog "[MAJ] Téléchargement : $($m.Url)"
}

# Signature RSA/SHA-256 de « BiblioTech-Widget|<version>|<SHA-256 du zip> » par la clé privée
# de l'éditeur (build-release.ps1) ; vérifiée avec Config.ReleasePublicKey. Le lien version +
# empreinte empêche de faire passer un ancien zip légitime pour une nouvelle version.
function Test-BtReleaseSignature {
    param($Ctx, [string]$Version, [string]$Sha, [string]$Sig)
    $pub = [string]$Ctx.Config.ReleasePublicKey
    if (-not $pub -or -not $Sig -or -not $Version) { return $false }
    try {
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider((New-Object System.Security.Cryptography.CspParameters 24))
        $rsa.FromXmlString($pub)
        return $rsa.VerifyData([Text.Encoding]::UTF8.GetBytes("BiblioTech-Widget|$Version|$Sha"), 'SHA256', [Convert]::FromBase64String($Sig))
    } catch { Write-BtLog "[MAJ] Vérification de signature impossible : $($_.Exception.Message)"; return $false }
}

function Complete-BtUpdateDownload {
    param($Ctx, $R)
    $t = $Ctx.Update.Target
    if (-not $R.Ok -or -not (Test-Path -LiteralPath $t.Zip)) {
        Write-BtLog "[MAJ] Téléchargement KO : $($R.Error)"
        Show-BtFlash $Ctx 'Échec du téléchargement de la mise à jour (réseau / proxy ?).'
        return
    }
    $sha = (Get-FileHash -LiteralPath $t.Zip -Algorithm SHA256).Hash.ToUpperInvariant()
    # Empreinte ET signature OBLIGATOIRES : un manifeste qui n'en a pas est refusé.
    if (-not $t.Manifest.Sha256 -or $sha -ne $t.Manifest.Sha256) {
        Write-BtLog "[MAJ] Empreinte SHA-256 absente ou invalide (attendu '$($t.Manifest.Sha256)', obtenu $sha) : mise à jour annulée."
        Remove-Item -LiteralPath $t.Zip -Force -ErrorAction SilentlyContinue
        Show-BtFlash $Ctx 'Mise à jour annulée : fichier corrompu (empreinte invalide).'
        return
    }
    if (-not (Test-BtReleaseSignature $Ctx $t.Manifest.Version $sha $t.Manifest.Sig)) {
        Write-BtLog "[MAJ] SIGNATURE absente ou invalide pour la version $($t.Manifest.Version) : mise à jour REFUSÉE (fichier non publié par l'éditeur ?)."
        Remove-Item -LiteralPath $t.Zip -Force -ErrorAction SilentlyContinue
        Show-BtFlash $Ctx 'Mise à jour refusée : signature invalide. Prévenez l''administrateur de Biblio-Tech.'
        return
    }
    Write-BtLog "[MAJ] Signature de la version $($t.Manifest.Version) vérifiée."
    Start-BtUpdater $Ctx $t.Zip $t.Manifest.Version
}

# Écrit et lance l'updater détaché, puis ferme l'application.
function Start-BtUpdater {
    param($Ctx, [string]$Zip, [string]$Version)
    $updater = @'
param([int]$WaitPid, [string]$Zip, [string]$AppDir, [string]$Version)
$log = Join-Path (Split-Path $AppDir -Parent) 'app_debug.log'
function L([string]$m) { try { Add-Content -LiteralPath $log -Value ("{0} [UPDATER] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8 } catch { } }
try {
    if ($WaitPid -gt 0) { try { Wait-Process -Id $WaitPid -Timeout 90 -ErrorAction SilentlyContinue } catch { } }
    Start-Sleep -Milliseconds 800
    $tmp = Join-Path $env:TEMP ('btupd_' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $Zip -DestinationPath $tmp -Force
    $inner = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'BiblioTechWidget.ps1') } | Select-Object -First 1
    $src = if ($inner) { $inner.FullName } else { $tmp }
    if (-not (Test-Path (Join-Path $src 'BiblioTechWidget.ps1'))) { throw 'archive invalide (BiblioTechWidget.ps1 absent)' }
    $done = $false
    for ($i = 1; $i -le 6 -and -not $done; $i++) {
        try { Copy-Item -Path (Join-Path $src '*') -Destination $AppDir -Recurse -Force -ErrorAction Stop; $done = $true }
        catch { L "Tentative $i : fichiers verrouillés ($($_.Exception.Message))"; Start-Sleep -Seconds 2 }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    if ($done) { L "Version $Version installée dans $AppDir."; Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue }
    else { L 'ECHEC : copie impossible, ancienne version conservée.' }
} catch { L ("ECHEC : " + $_.Exception.Message) }
finally {
    $vbs = Join-Path $AppDir 'Start-BiblioTech.vbs'
    if (Test-Path $vbs) { Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $vbs + '"') -WorkingDirectory $AppDir }
}
'@
    $path = Join-Path (Join-Path $Ctx.DataDir 'update') 'updater.ps1'
    [System.IO.File]::WriteAllText($path, $updater, (New-Object System.Text.UTF8Encoding $true))
    $args_ = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -WaitPid {1} -Zip "{2}" -AppDir "{3}" -Version "{4}"' -f $path, $PID, $Zip, $Ctx.AppRoot, $Version
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args_ -WindowStyle Hidden
    Write-BtLog "[MAJ] Updater lancé (version $Version) : fermeture de l'application."
    Stop-BtApp $Ctx
}
