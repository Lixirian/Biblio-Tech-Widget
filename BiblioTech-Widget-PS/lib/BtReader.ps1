# ============================================================================
#  Lecteur intégré : fenêtre redimensionnable avec un WebView2 qui partage le
#  profil (donc la session SSO) du WebView principal. Barre d'outils sombre,
#  « mode lecture » qui masque le chrome Confluence (CSS injecté, réversible).
# ============================================================================

$script:BtReaderXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Biblio-Tech · Lecteur" Width="1180" Height="860" MinWidth="640" MinHeight="420"
        WindowStartupLocation="CenterScreen" Background="#0F172A" FontFamily="Segoe UI" FontSize="13" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="TbBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#C9D4E5"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="MinWidth" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="8,0">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#2AFFFFFF"/><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0B1220" BorderBrush="#0088CE" BorderThickness="0,0,0,2" Padding="8,7">
      <DockPanel>
        <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
          <Button x:Name="BackBtn" Style="{StaticResource TbBtn}" ToolTip="Précédent"><TextBlock Text="&#xE72B;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"/></Button>
          <Button x:Name="FwdBtn" Style="{StaticResource TbBtn}" ToolTip="Suivant"><TextBlock Text="&#xE72A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"/></Button>
          <Button x:Name="ReloadBtn" Style="{StaticResource TbBtn}" ToolTip="Recharger"><TextBlock Text="&#xE72C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"/></Button>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button x:Name="ReadBtn" Style="{StaticResource TbBtn}" ToolTip="Mode lecture : masque les menus Confluence">
            <StackPanel Orientation="Horizontal"><TextBlock x:Name="ReadIcon" Text="&#xE736;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" VerticalAlignment="Center"/><TextBlock x:Name="ReadText" Text="Lecture" Margin="6,0,0,0" FontSize="12"/></StackPanel>
          </Button>
          <Button x:Name="PinBtn" Style="{StaticResource TbBtn}" ToolTip="Épingler"><TextBlock x:Name="PinIcon" Text="&#xE718;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"/></Button>
          <Button x:Name="CopyBtn" Style="{StaticResource TbBtn}" ToolTip="Copier le lien"><TextBlock Text="&#xE8C8;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"/></Button>
          <Button x:Name="WebBtn" Style="{StaticResource TbBtn}" ToolTip="Ouvrir dans le navigateur">
            <StackPanel Orientation="Horizontal"><TextBlock Text="&#xE8A7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" VerticalAlignment="Center"/><TextBlock Text="Navigateur" Margin="6,0,0,0" FontSize="12"/></StackPanel>
          </Button>
        </StackPanel>
        <StackPanel Margin="12,0" VerticalAlignment="Center">
          <TextBlock x:Name="TitleText" Foreground="#E6EDF7" FontSize="14" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
          <TextBlock x:Name="SubText" Foreground="#8193B2" FontSize="11" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </DockPanel>
    </Border>
    <Grid x:Name="Host" Background="#FFFFFF"/>
  </DockPanel>
</Window>
'@

# Politique de navigation du lecteur : 'stay' (reste dans le lecteur) | 'external' (navigateur
# par défaut) | 'block'. Confluence et l'IdP appris : 'stay' ; une REDIRECTION vers un serveur
# du domaine SSO (AuthAllowlist, ex. *.sncf.fr) aussi (chaîne d'authentification).
function Get-BtReaderNavPolicy {
    param($Ctx, [string]$Url, [bool]$Redirect)
    $u = $null; try { $u = [uri]$Url } catch { }
    if (-not $u -or -not $u.IsAbsoluteUri) { return 'block' }
    if ($u.Scheme -eq 'about' -and $u.AbsoluteUri -eq 'about:blank') { return 'stay' }
    if ($u.Scheme -notin @('https', 'http')) { return 'block' }
    if (Test-BtTrustedHost $Ctx $u.Host) { return 'stay' }
    if ($Redirect -and $u.Scheme -eq 'https' -and @(([string]$Ctx.Config.AuthAllowlist -split '[,;\s]+') | Where-Object { $_ -and $u.Host -like $_ }).Count) { return 'stay' }
    return 'external'
}

function New-BtReaderWindow {
    param($Ctx)
    $win = [System.Windows.Markup.XamlReader]::Parse($script:BtReaderXaml)
    $r = $Ctx.Reader
    $r.Window = $win
    $r.Ui = @{}
    foreach ($n in @('BackBtn', 'FwdBtn', 'ReloadBtn', 'ReadBtn', 'ReadIcon', 'ReadText', 'PinBtn', 'PinIcon', 'CopyBtn', 'WebBtn', 'TitleText', 'SubText', 'Host')) { $r.Ui[$n] = $win.FindName($n) }
    $ico = New-BtImageSource (Get-BtAppIconPath 'png') 64
    if ($ico) { $win.Icon = $ico }
    Register-BtWindowIcon $win

    $wv = New-BtWebView $Ctx
    $r.WebView = $wv
    [void]$r.Ui.Host.Children.Add($wv)

    $wv.add_CoreWebView2InitializationCompleted({ param($s, $e)
        if (-not $e.IsSuccess) { Write-BtLog "[LECTEUR] Init WebView2 KO : $($e.InitializationException.Message)"; return }
        $cw = $s.CoreWebView2
        # Pas de F12 ni d'autorisation ; téléchargements (pièces jointes) depuis Confluence seulement.
        Set-BtWebHardening $script:Ctx $cw -Downloads
        # Liens « nouvel onglet » : même règle que la navigation (Confluence -> lecteur, reste -> navigateur).
        $cw.add_NewWindowRequested({ param($a, $b)
            $b.Handled = $true
            $u = [string]$b.Uri
            switch (Get-BtReaderNavPolicy $script:Ctx $u $false) {
                'stay'     { try { $script:Ctx.Reader.WebView.CoreWebView2.Navigate($u) } catch { } }
                'external' { Open-BtExternal $u }
                default    { Write-BtLog "[SECU] Ouverture bloquée dans le lecteur : $u" }
            } })
        # Le lecteur n'affiche QUE Confluence (et l'IdP pendant une redirection SSO) : tout autre
        # site part dans le navigateur, qui montre sa barre d'adresse (pas de fausse page de
        # connexion dans une fenêtre « Biblio-Tech »). Schémas non web : bloqués.
        $cw.add_NavigationStarting({ param($a, $b)
            $u = [string]$b.Uri
            $p = Get-BtReaderNavPolicy $script:Ctx $u ([bool]$b.IsRedirected)
            if ($p -eq 'stay') { return }
            $b.Cancel = $true
            if ($p -eq 'external') { Open-BtExternal $u } else { Write-BtLog "[SECU] Navigation bloquée dans le lecteur : $u" } })
        $cw.add_DocumentTitleChanged({ param($a, $b)
            try { $t = [string]$a.DocumentTitle; if ($t) { $script:Ctx.Reader.Ui.TitleText.Text = ($t -replace '\s+-\s+Confluence.*$', '') } } catch { } })
        $cw.add_DOMContentLoaded({ param($a, $b) Update-BtReaderMode $script:Ctx })
        # Thème des pages : celui de Windows (clair / sombre).
        Set-BtWebTheme $script:Ctx $s
        Register-BtDarkPages $script:Ctx $cw
    })
    $r.Ui.Host.Background = if ($Ctx.Dark) { Get-BtBrush 'Panel' } else { [System.Windows.Media.Brushes]::White }
    $wv.add_NavigationCompleted({ param($s, $e)
        Update-BtReaderMode $script:Ctx
        try {
            $u = [string]$s.Source
            $script:Ctx.Reader.Url = $u
            $script:Ctx.Reader.Ui.SubText.Text = $u
            $script:Ctx.Reader.Ui.BackBtn.IsEnabled = $s.CanGoBack
            $script:Ctx.Reader.Ui.FwdBtn.IsEnabled = $s.CanGoForward
        } catch { }
    })

    $r.Ui.BackBtn.Add_Click({ try { if ($script:Ctx.Reader.WebView.CanGoBack) { $script:Ctx.Reader.WebView.GoBack() } } catch { } })
    $r.Ui.FwdBtn.Add_Click({ try { if ($script:Ctx.Reader.WebView.CanGoForward) { $script:Ctx.Reader.WebView.GoForward() } } catch { } })
    $r.Ui.ReloadBtn.Add_Click({ try { $script:Ctx.Reader.WebView.Reload() } catch { } })
    $r.Ui.ReadBtn.Add_Click({
        $script:Ctx.State.ReaderMode = -not $script:Ctx.State.ReaderMode
        Save-BtState $script:Ctx.State
        Update-BtReaderMode $script:Ctx
    })
    $r.Ui.PinBtn.Add_Click({ $it = $script:Ctx.Reader.Item; if ($it) { Invoke-BtTogglePin $script:Ctx $it; Update-BtReaderPin $script:Ctx } })
    $r.Ui.CopyBtn.Add_Click({ $u = if ($script:Ctx.Reader.Url) { $script:Ctx.Reader.Url } else { [string]$script:Ctx.Reader.Item.url }; try { [System.Windows.Clipboard]::SetText($u) } catch { } })
    $r.Ui.WebBtn.Add_Click({ $u = if ($script:Ctx.Reader.Url) { $script:Ctx.Reader.Url } else { [string]$script:Ctx.Reader.Item.url }; Open-BtExternal $u })
    $win.Add_Closing({ param($s, $e) if (-not $script:Ctx.Quitting) { $e.Cancel = $true; $s.Hide() } })
    return $win
}

function Open-BtReader {
    param($Ctx, $Item)
    $url = [string]$Item.url
    if (-not (Test-BtHttpUrl $url)) { return }
    if (-not $script:BtWebView2Ok -or (Get-BtReaderNavPolicy $Ctx $url $false) -ne 'stay') { Open-BtExternal $url; return }
    $r = $Ctx.Reader
    if (-not $r.Window) { New-BtReaderWindow $Ctx | Out-Null }
    $r.Item = $Item
    $r.Url = $url
    $r.Ui.TitleText.Text = Get-BtPlainText ([string]$Item.title)
    $r.Ui.SubText.Text = (@(@([string]$Item.space, [string]$Item.parent) | Where-Object { $_ }) -join '  ›  ')
    Update-BtReaderPin $Ctx
    Update-BtReaderMode $Ctx
    try { $r.WebView.Source = [uri]$url } catch { Write-BtLog "[LECTEUR] Navigation KO : $($_.Exception.Message)" }
    $w = $r.Window
    $w.Show()
    if ($w.WindowState -eq [System.Windows.WindowState]::Minimized) { $w.WindowState = [System.Windows.WindowState]::Normal }
    $w.Activate() | Out-Null
    Write-BtLog "[LECTEUR] $url"
}

function Update-BtReaderPin {
    param($Ctx)
    $r = $Ctx.Reader
    if (-not $r.Window -or -not $r.Item) { return }
    $p = Test-BtPinned $Ctx.State $r.Item
    $r.Ui.PinIcon.Text = if ($p) { [string][char]0xE840 } else { [string][char]0xE718 }
    $r.Ui.PinIcon.Foreground = Get-BtBrush $(if ($p) { 'Accent' } else { '#C9D4E5' })
}

# Applique (ou retire) le CSS du mode lecture sur la page courante du lecteur.
function Update-BtReaderMode {
    param($Ctx)
    $r = $Ctx.Reader
    if (-not $r.Window) { return }
    $on = [bool]$Ctx.State.ReaderMode
    $r.Ui.ReadText.Foreground = Get-BtBrush $(if ($on) { 'Accent' } else { '#C9D4E5' })
    $r.Ui.ReadIcon.Foreground = Get-BtBrush $(if ($on) { 'Accent' } else { '#C9D4E5' })
    try {
        $cw = $r.WebView.CoreWebView2
        if ($cw -and ([uri]$cw.Source).Host -eq $Ctx.ConfHost) { $cw.ExecuteScriptAsync((Get-BtReaderCssJS $on)) | Out-Null }
    } catch { }
}
