# ============================================================================
#  Fenêtre principale : application fenêtrée classique (barre de titre intégrée
#  via WindowChrome : déplacement, redimensionnement, ancrage Windows natifs),
#  rendu des résultats, filtres, statut, menu, raccourci global.
#  Fermer (X) masque la fenêtre dans la zone de notification ; « Quitter » arrête.
# ============================================================================

$script:BtXamlResources = @'
<Window.Resources>
  <Style x:Key="IconBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#C9D4E5"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Width" Value="32"/>
    <Setter Property="Height" Value="32"/>
    <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="bd" Property="Background" Value="#2AFFFFFF"/>
              <Setter Property="Foreground" Value="#FFFFFF"/>
            </Trigger>
            <Trigger Property="IsPressed" Value="True">
              <Setter TargetName="bd" Property="Background" Value="#40FFFFFF"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="PrimaryBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#FFFFFF"/>
    <Setter Property="Background" Value="#0088CE"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Padding" Value="16,7"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1A9BE0"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Opacity" Value="0.5"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="LinkBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#4FB3FF"/>
    <Setter Property="FontSize" Value="11.5"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="Transparent" CornerRadius="5" Padding="6,3">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1A4FB3FF"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="UpdateBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#0B1220"/>
    <Setter Property="FontSize" Value="11.5"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="#FFD166" CornerRadius="12" Padding="10,3">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#FFE09A"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="CaptionBtn" TargetType="Button">
    <Setter Property="Foreground" Value="#C9D4E5"/>
    <Setter Property="Width" Value="46"/>
    <Setter Property="Height" Value="44"/>
    <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
    <Setter Property="FontSize" Value="10"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="Transparent">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1FFFFFFF"/><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="#33FFFFFF"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="CloseBtn" TargetType="Button" BasedOn="{StaticResource CaptionBtn}">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="bd" Background="Transparent">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#C42B1C"/><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Background" Value="#A3261A"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="8"/>
    <Setter Property="MinWidth" Value="8"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Grid Background="Transparent">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb">
                      <Border CornerRadius="4" Background="#3A4D70" Margin="1,2"/>
                    </ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ToolTip">
    <Setter Property="Background" Value="#1B2947"/>
    <Setter Property="Foreground" Value="#E6EDF7"/>
    <Setter Property="BorderBrush" Value="#2F5C8A"/>
    <Setter Property="FontSize" Value="11.5"/>
  </Style>
</Window.Resources>
'@

# Bloc logo (zone de la barre de titre : sert aussi de poignée de déplacement).
$script:BtXamlLogo = @'
<StackPanel Orientation="Horizontal" VerticalAlignment="Center" x:Name="LogoArea">
  <Grid Width="30" Height="30">
    <Border x:Name="LogoBadge" CornerRadius="8">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#0088CE" Offset="0"/>
          <GradientStop Color="#6D5BD0" Offset="1"/>
        </LinearGradientBrush>
      </Border.Background>
      <TextBlock Text="&#xE8F1;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <Image x:Name="LogoImg" Visibility="Collapsed" RenderOptions.BitmapScalingMode="HighQuality"/>
  </Grid>
  <StackPanel Margin="9,0,0,0" VerticalAlignment="Center">
    <TextBlock Text="Biblio-Tech" FontSize="14" FontWeight="Bold" Foreground="#E6EDF7"/>
    <TextBlock x:Name="SubTitle" Text="Base de connaissances" FontSize="10" Foreground="#8193B2"/>
  </StackPanel>
</StackPanel>
'@

# Champ de recherche (réutilisé).
$script:BtXamlSearch = @'
<Border x:Name="SearchShell" Height="40" CornerRadius="10" Background="#16213A" BorderBrush="#2B3A5C" BorderThickness="1">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="34"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="&#xE721;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Foreground="#8193B2" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <TextBlock x:Name="SearchHint" Grid.Column="1" Text="Décrivez votre besoin ou tapez des mots-clés…" Foreground="#5D6F8F" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
    <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" BorderThickness="0" Foreground="#E6EDF7" CaretBrush="#FFFFFF" SelectionBrush="#0088CE" FontSize="13.5" VerticalAlignment="Center" Padding="0"/>
    <Button x:Name="ClearBtn" Grid.Column="2" Style="{StaticResource IconBtn}" Width="24" Height="24" FontSize="9" Content="&#xE711;" ToolTip="Effacer (Échap)" Visibility="Collapsed"/>
    <Border Grid.Column="3" CornerRadius="4" Background="#1F2C47" Margin="4,0,7,0" Padding="6,1" VerticalAlignment="Center">
      <TextBlock x:Name="HotkeyText" FontSize="10" Foreground="#8193B2"/>
    </Border>
    <ProgressBar x:Name="BusyBar" Grid.ColumnSpan="4" Height="2" VerticalAlignment="Bottom" Margin="8,0,8,0" IsIndeterminate="True" Foreground="#0088CE" Background="Transparent" BorderThickness="0" Visibility="Collapsed"/>
  </Grid>
</Border>
'@

$script:BtXamlStatus = @'
<StackPanel Orientation="Horizontal" VerticalAlignment="Center" x:Name="StatusArea" Background="Transparent">
  <Ellipse x:Name="StatusDot" Width="8" Height="8" Fill="#8193B2" VerticalAlignment="Center"/>
  <TextBlock x:Name="StatusText" Margin="7,0,0,0" FontSize="11.5" Foreground="#B8C4D8" VerticalAlignment="Center" Text="Démarrage…"/>
</StackPanel>
'@

$script:BtXamlBody = @'
<DockPanel>
  <WrapPanel x:Name="FilterHost" DockPanel.Dock="Top" Margin="14,12,10,4"/>
  <Border DockPanel.Dock="Bottom" BorderBrush="#1E2A44" BorderThickness="0,1,0,0" Padding="14,7,10,8">
    <DockPanel>
      <Button x:Name="OpenHomeBtn" DockPanel.Dock="Right" Style="{StaticResource LinkBtn}" Content="Ouvrir Biblio-Tech dans le navigateur ↗"/>
      <TextBlock x:Name="FooterText" FontSize="11" Foreground="#5D6F8F" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
    </DockPanel>
  </Border>
  <ScrollViewer x:Name="ResultsScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="12,2,8,6">
    <StackPanel x:Name="ResultsPanel"/>
  </ScrollViewer>
</DockPanel>
'@

$script:BtXamlButtons = @'
<StackPanel Orientation="Horizontal" VerticalAlignment="Top" WindowChrome.IsHitTestVisibleInChrome="True">
  <Button x:Name="UpdateBtn" Style="{StaticResource UpdateBtn}" Margin="0,11,8,0" VerticalAlignment="Top" Visibility="Collapsed" ToolTip="Une nouvelle version est disponible : cliquer pour voir les nouveautés"/>
  <Button x:Name="DashBtn" Style="{StaticResource IconBtn}" Margin="0,6,4,0" VerticalAlignment="Top" Content="&#xE9D2;" ToolTip="Tableau de bord (activité, commentaires, consignes phares, export Excel)"/>
  <Button x:Name="MenuBtn" Style="{StaticResource IconBtn}" Margin="0,6,10,0" VerticalAlignment="Top" Content="&#xE712;" ToolTip="Menu"/>
  <Button x:Name="MinBtn" Style="{StaticResource CaptionBtn}" Content="&#xE921;" ToolTip="Réduire"/>
  <Button x:Name="MaxBtn" Style="{StaticResource CaptionBtn}" Content="&#xE922;" ToolTip="Agrandir"/>
  <Button x:Name="CloseBtn" Style="{StaticResource CloseBtn}" Content="&#xE8BB;" ToolTip="Fermer (Biblio-Tech reste disponible dans la zone de notification)"/>
</StackPanel>
'@

function Get-BtWindowXaml {
    param($Ctx)
    $w = [int]$Ctx.Config.WindowWidth; $h = [int]$Ctx.Config.WindowHeight
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Biblio-Tech" Width="$w" Height="$h" MinWidth="620" MinHeight="440" WindowStartupLocation="CenterScreen"
        Background="#0F172A" ShowInTaskbar="True" UseLayoutRounding="True" FontFamily="Segoe UI" FontSize="13" TextOptions.TextFormattingMode="Display">
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="44" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  $script:BtXamlResources
  <Border x:Name="Root" BorderBrush="#22314F" BorderThickness="1">
    <DockPanel>
      <Border x:Name="Bar" DockPanel.Dock="Top" Background="#0B1220" Height="56" Padding="14,0,0,0">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          $script:BtXamlLogo
          <Grid Grid.Column="2" Margin="0,0,16,0" WindowChrome.IsHitTestVisibleInChrome="True">$script:BtXamlStatus</Grid>
          <Grid Grid.Column="3">$script:BtXamlButtons</Grid>
        </Grid>
      </Border>
      <Border DockPanel.Dock="Top" Background="#0B1220" BorderBrush="#0088CE" BorderThickness="0,0,0,2" Padding="18,4,18,14">
        <Grid MaxWidth="900" HorizontalAlignment="Stretch">$script:BtXamlSearch</Grid>
      </Border>
      $script:BtXamlBody
    </DockPanel>
  </Border>
</Window>
"@
}

# Construit la fenêtre, collecte les éléments nommés dans $Ctx.Ui et câble les événements.
function New-BtWindow {
    param($Ctx)
    $win = [System.Windows.Markup.XamlReader]::Parse((Get-BtWindowXaml $Ctx))
    $ui = @{ Suppress = $false; LastState = [System.Windows.WindowState]::Normal; TrayTipShown = $false }
    foreach ($n in @('Root', 'Bar', 'LogoArea', 'SubTitle', 'SearchShell', 'SearchHint', 'SearchBox', 'ClearBtn', 'HotkeyText', 'BusyBar',
            'StatusArea', 'StatusDot', 'StatusText', 'FilterHost', 'ResultsScroll', 'ResultsPanel', 'FooterText', 'OpenHomeBtn',
            'UpdateBtn', 'DashBtn', 'MenuBtn', 'MinBtn', 'MaxBtn', 'CloseBtn')) {
        $ui[$n] = $win.FindName($n)
    }
    $Ctx.Ui = $ui
    $Ctx.Window = $win
    $ui.HotkeyText.Text = [string]$Ctx.Config.Hotkey
    # Icône de l'application (repli : pastille dégradée + glyphe).
    $logo = New-BtImageSource (Get-BtAppIconPath 'png') 64
    if ($logo) {
        $win.Icon = $logo
        $img = $win.FindName('LogoImg'); $img.Source = $logo; $img.Visibility = [System.Windows.Visibility]::Visible
        $win.FindName('LogoBadge').Visibility = [System.Windows.Visibility]::Collapsed
    }
    Register-BtWindowIcon $win
    # Retour sur la fenêtre : contrôle de mise à jour immédiat (au plus une fois par minute).
    $win.Add_Activated({
        $u = $script:Ctx.Update
        if (-not $u.Phase -and ((Get-Date) - $u.LastCheckAt).TotalSeconds -ge 60) { $u.NextCheck = Get-Date }
    })
    Restore-BtWindowBounds $Ctx

    $ui.SearchBox.Add_TextChanged({ param($s, $e)
        $u = $script:Ctx.Ui
        $has = [bool]$s.Text
        $u.SearchHint.Visibility = if ($has) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        $u.ClearBtn.Visibility = if ($has) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        if ($u.Suppress) { return }
        $script:Ctx.Search.Typed = $s.Text
        # Une phrase (4 mots et plus) laisse un peu plus de temps pour finir de taper.
        $ms = [int]$script:Ctx.Config.SearchDebounceMs
        if (@(([string]$s.Text).Trim() -split '\s+').Count -ge 4) { $ms = [Math]::Max($ms, 900) }
        $script:Ctx.Search.DebounceAt = (Get-Date).AddMilliseconds($ms)
    })
    $ui.SearchBox.Add_PreviewKeyDown({ param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $e.Handled = $true
            $script:Ctx.Search.DebounceAt = $null
            Request-BtSearch $script:Ctx $s.Text 0 'search' -Force
            Add-BtHistory $script:Ctx.State $s.Text $script:Ctx.Config.HistoryMax
        } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $e.Handled = $true
            if ($s.Text) { $s.Text = '' }
            elseif (-not $script:Ctx.Browse) { [void](Pop-BtHomeNav $script:Ctx) }
        }
    })
    $ui.SearchBox.Add_GotKeyboardFocus({ param($s, $e) $script:Ctx.Ui.SearchShell.BorderBrush = Get-BtBrush 'Accent' })
    $ui.SearchBox.Add_LostKeyboardFocus({ param($s, $e) $script:Ctx.Ui.SearchShell.BorderBrush = Get-BtBrush '#2B3A5C' })
    $ui.ClearBtn.Add_Click({ $script:Ctx.Ui.SearchBox.Text = ''; $script:Ctx.Ui.SearchBox.Focus() | Out-Null })
    # Bouton « précédent » de la souris : page précédente de l'accueil en tuiles.
    $ui.ResultsScroll.Add_PreviewMouseUp({ param($x, $e)
        $c = $script:Ctx
        if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::XButton1 -and -not $c.Search.ShownQuery -and -not $c.Browse) { $e.Handled = [bool](Pop-BtHomeNav $c) }
    })
    $ui.StatusArea.Add_MouseLeftButtonUp({ if (-not $script:Ctx.Ready) { Start-BtInteractiveLogin $script:Ctx } })
    $ui.MenuBtn.Add_Click({ try { $script:Ctx.TrayMenu.Show([System.Windows.Forms.Cursor]::Position) } catch { } })
    $ui.DashBtn.Add_Click({ Show-BtDashboard $script:Ctx })
    $ui.OpenHomeBtn.Add_Click({ Open-BtExternal $script:Ctx.HomeUrl })
    $ui.UpdateBtn.Add_Click({ Invoke-BtPromptAndUpdate $script:Ctx })
    $ui.MinBtn.Add_Click({ $script:Ctx.Window.WindowState = [System.Windows.WindowState]::Minimized })
    $ui.MaxBtn.Add_Click({
        $w = $script:Ctx.Window
        $w.WindowState = if ($w.WindowState -eq [System.Windows.WindowState]::Maximized) { [System.Windows.WindowState]::Normal } else { [System.Windows.WindowState]::Maximized }
    })
    $ui.CloseBtn.Add_Click({ Hide-BtMainWindow $script:Ctx })

    $win.Add_StateChanged({ param($s, $e) Update-BtWindowState $script:Ctx })
    # Fermer (X, Alt+F4) = masquer dans la zone de notification ; seul « Quitter » arrête l'appli.
    $win.Add_Closing({ param($s, $e)
        if (-not $script:Ctx.Quitting -and $s -eq $script:Ctx.Window) { $e.Cancel = $true; Hide-BtMainWindow $script:Ctx }
    })

    Render-BtFilters $Ctx
    Update-BtWindowState $Ctx
    return $win
}

# Agrandie, une fenêtre WindowChrome déborde de l'écran de l'épaisseur du cadre :
# on compense par une marge. Met aussi à jour le glyphe Agrandir / Restaurer.
function Update-BtWindowState {
    param($Ctx)
    $w = $Ctx.Window; $ui = $Ctx.Ui
    if (-not $w -or -not $ui) { return }
    $max = $w.WindowState -eq [System.Windows.WindowState]::Maximized
    $ui.Root.Margin = if ($max) { New-BtThickness 7 } else { New-BtThickness 0 }
    $ui.Root.BorderThickness = if ($max) { New-BtThickness 0 } else { New-BtThickness 1 }
    $ui.MaxBtn.Content = if ($max) { [string][char]0xE923 } else { [string][char]0xE922 }
    $ui.MaxBtn.ToolTip = if ($max) { 'Restaurer' } else { 'Agrandir' }
    if ($w.WindowState -ne [System.Windows.WindowState]::Minimized) { $ui.LastState = $w.WindowState }
}

# --- Taille / position mémorisées (state.json) --------------------------------
function Restore-BtWindowBounds {
    param($Ctx)
    $win = $Ctx.Window
    $b = @(([string]$Ctx.State.Bounds) -split ',' | ForEach-Object { $d = 0.0; if ([double]::TryParse($_, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { $d } })
    if ($b.Count -eq 4 -and $b[2] -ge 400 -and $b[3] -ge 300) {
        # Ne restaure que si la barre de titre reste visible sur un écran actuel
        # (écran débranché, changement de résolution...).
        $vs = New-Object System.Windows.Rect ([System.Windows.SystemParameters]::VirtualScreenLeft), ([System.Windows.SystemParameters]::VirtualScreenTop), ([System.Windows.SystemParameters]::VirtualScreenWidth), ([System.Windows.SystemParameters]::VirtualScreenHeight)
        $title = New-Object System.Windows.Rect $b[0], $b[1], $b[2], 40
        if ($vs.IntersectsWith($title) -and [System.Windows.Rect]::Intersect($vs, $title).Width -ge 120) {
            $win.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
            $win.Left = $b[0]; $win.Top = $b[1]; $win.Width = $b[2]; $win.Height = $b[3]
        }
    }
    if ($Ctx.State.Maximized) { $win.WindowState = [System.Windows.WindowState]::Maximized }
}

function Save-BtWindowBounds {
    param($Ctx)
    $win = $Ctx.Window
    if (-not $win) { return }
    try {
        $r = $win.RestoreBounds
        if ($r.IsEmpty -or $r.Width -lt 100) { $r = New-Object System.Windows.Rect $win.Left, $win.Top, $win.ActualWidth, $win.ActualHeight }
        $inv = [System.Globalization.CultureInfo]::InvariantCulture
        $Ctx.State.Bounds = (@($r.Left, $r.Top, $r.Width, $r.Height) | ForEach-Object { ([math]::Round($_)).ToString($inv) }) -join ','
        $Ctx.State.Maximized = ($Ctx.Ui.LastState -eq [System.Windows.WindowState]::Maximized)
        Save-BtState $Ctx.State
    } catch { Write-BtLog "[UI] Mémorisation de la fenêtre : $($_.Exception.Message)" }
}

function Show-BtMainWindow {
    param($Ctx)
    $win = New-BtWindow $Ctx
    $win.Show()
    Set-BtStatus $Ctx $Ctx.StatusKind $Ctx.StatusText
    Update-BtUpdateBadge $Ctx
    Render-BtResults $Ctx
}

# Masque la fenêtre dans la zone de notification (session SSO conservée).
function Hide-BtMainWindow {
    param($Ctx)
    $w = $Ctx.Window
    if (-not $w) { return }
    Save-BtWindowBounds $Ctx
    $w.Hide()
    if (-not $Ctx.Ui.TrayTipShown -and $Ctx.Tray) {
        $Ctx.Ui.TrayTipShown = $true
        try { $Ctx.Tray.ShowBalloonTip(4000, 'Biblio-Tech reste disponible', ("Rouvrez-le avec {0} ou en cliquant sur cette icône. « Quitter » est dans son menu." -f $Ctx.Config.Hotkey), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    }
}

# Affiche la fenêtre au premier plan, recherche prête à la saisie (raccourci global,
# icône de notification, relance du raccourci alors que l'appli tourne déjà).
function Show-BtSearch {
    param($Ctx)
    try {
        $w = $Ctx.Window
        if (-not $w.IsVisible) { $w.Show() }
        if ($w.WindowState -eq [System.Windows.WindowState]::Minimized) { $w.WindowState = $Ctx.Ui.LastState }
        $w.Activate() | Out-Null
        $Ctx.Ui.SearchBox.Focus() | Out-Null
        $Ctx.Ui.SearchBox.SelectAll()
    } catch { Write-BtLog "[UI] Show-BtSearch : $($_.Exception.Message)" }
}

# --- Statut / pied de panneau -------------------------------------------------
function Set-BtStatus {
    param($Ctx, [string]$Kind, [string]$Text)
    $Ctx.StatusKind = $Kind; $Ctx.StatusText = $Text
    $ui = $Ctx.Ui
    if (-not $ui) { return }
    $color = switch ($Kind) { 'ok' { 'Ok' } 'busy' { 'Accent' } 'warn' { 'Warn' } 'error' { 'Error' } default { 'Muted' } }
    $ui.StatusDot.Fill = Get-BtBrush $color
    $ui.StatusText.Text = $Text
    $ui.StatusArea.ToolTip = if ($Kind -eq 'warn') { 'Cliquer pour afficher la fenêtre de connexion' } else { $Ctx.Config.BaseUrl }
}

function Update-BtFooter {
    param($Ctx)
    $ui = $Ctx.Ui
    if (-not $ui) { return }
    if ($Ctx.FlashUntil -and (Get-Date) -lt $Ctx.FlashUntil) { $ui.FooterText.Text = $Ctx.FlashText; return }
    $s = $Ctx.Search
    if ($s.ShownQuery -and $s.LastVia) {
        $ui.FooterText.Text = ('{0} résultat(s) · {1} ms · source : {2}' -f $s.Total, $s.LastMs, $s.LastVia)
    } else {
        $ui.FooterText.Text = ('{0} · v{1}' -f ([uri]$Ctx.Config.BaseUrl).Host, $Ctx.Config.Version)
    }
}

function Show-BtFlash {
    param($Ctx, [string]$Text)
    $Ctx.FlashText = $Text
    $Ctx.FlashUntil = (Get-Date).AddSeconds(3)
    Update-BtFooter $Ctx
}

function Copy-BtLink {
    param($Ctx, $Item)
    try { [System.Windows.Clipboard]::SetText([string]$Item.url); Show-BtFlash $Ctx 'Lien copié dans le presse-papiers.' }
    catch { Show-BtFlash $Ctx 'Presse-papiers indisponible, réessayez.' }
}

function Invoke-BtTogglePin {
    param($Ctx, $Item)
    $now = Switch-BtPin $Ctx.State $Item
    Show-BtFlash $Ctx $(if ($now) { 'Épinglé : visible sur l''accueil du widget.' } else { 'Retiré des épinglés.' })
    Render-BtResults $Ctx
}

# Actions des cartes de message.
function Invoke-BtAction {
    param($Ctx, [string]$Action)
    switch ($Action) {
        'login'   { Start-BtInteractiveLogin $Ctx }
        'retry'   { if ($Ctx.Search.ShownQuery) { Request-BtSearch $Ctx $Ctx.Search.ShownQuery 0 'search' -Force } else { Request-BtSearch $Ctx '' 0 'recent' } }
        'scopeAll' { $Ctx.State.Scope = 'all'; Save-BtState $Ctx.State; Render-BtFilters $Ctx; Request-BtSearch $Ctx $Ctx.Search.ShownQuery 0 'search' -Force }
        'more'    { Request-BtSearch $Ctx $Ctx.Search.ShownQuery (@($Ctx.Search.Results).Count) 'search' -Force }
        'copilot' {
            # Pas d'API : on ouvre l'agent dans le navigateur (SSO Microsoft 365 de l'utilisateur)
            # et la question est placée dans le presse-papiers.
            try { [System.Windows.Clipboard]::SetText([string]$Ctx.Search.ShownQuery) } catch { }
            Open-BtExternal ([string]$Ctx.Config.CopilotAgentUrl)
            Show-BtFlash $Ctx 'Question copiée : collez-la dans Copilot avec Ctrl+V.'
        }
        'clearHistory' { $Ctx.State.History = @(); Save-BtState $Ctx.State; Render-BtResults $Ctx }
    }
}

# Ouvre un fichier du dossier de données (rapport, journal) dans le Bloc-notes.
function Open-BtDataFile {
    param($Ctx, [string]$Name)
    $f = Join-Path $Ctx.DataDir $Name
    if (Test-Path -LiteralPath $f) { try { Start-Process notepad.exe -ArgumentList ('"' + $f + '"') } catch { } }
    else { Show-BtFlash $Ctx 'Pas encore d''analyse : elle se lance automatiquement après la connexion.' }
}

# --- Filtres -------------------------------------------------------------------
function Render-BtFilters {
    param($Ctx)
    $host_ = $Ctx.Ui.FilterHost
    if (-not $host_) { return }
    $host_.Children.Clear()
    $st = $Ctx.State
    # Filtres de type (pages / blogs / pièces jointes) et de tri retirés (jugés inutiles) :
    # la recherche porte sur tout, par pertinence. Seul le filtre d'espace reste, s'il est configuré.
    $groups = @()
    if ($Ctx.Config.SpaceKey) {
        $groups = @(@{ Key = 'Scope'; Items = @(@('space', "Espace $($Ctx.Config.SpaceKey)", [string][char]0xE8F1), @('all', 'Tout Biblio-Tech', [string][char]0xE774)) })
    }
    $first = $true
    foreach ($g in $groups) {
        if (-not $first) {
            $sep = New-Object System.Windows.Controls.Border
            $sep.Width = 1; $sep.Height = 18; $sep.Margin = New-BtThickness 4 3 10 9
            $sep.Background = Get-BtBrush 'Border'
            [void]$host_.Children.Add($sep)
        }
        $first = $false
        foreach ($it in $g.Items) {
            $chip = New-BtChip $it[1] ($st[$g.Key] -eq $it[0]) @{ Key = $g.Key; Value = $it[0] } $it[2]
            $chip.Add_MouseLeftButtonUp({ param($s, $e)
                $c = $script:Ctx
                $c.State[$s.Tag.Key] = $s.Tag.Value
                Save-BtState $c.State
                Render-BtFilters $c
                if ($c.Search.ShownQuery) { Request-BtSearch $c $c.Search.ShownQuery 0 'search' -Force }
            })
            [void]$host_.Children.Add($chip)
        }
    }
    # Onglets Accueil / Catégories (arborescence de l'index local à la place de l'accueil).
    if ($groups.Count) {
        $sep = New-Object System.Windows.Controls.Border
        $sep.Width = 1; $sep.Height = 18; $sep.Margin = New-BtThickness 4 3 10 9
        $sep.Background = Get-BtBrush 'Border'
        [void]$host_.Children.Add($sep)
    }
    foreach ($tab in @(@{ Browse = $false; Text = 'Accueil'; Glyph = [string][char]0xE80F }, @{ Browse = $true; Text = 'Catégories'; Glyph = [string][char]0xE8B7 })) {
        $chip = New-BtChip $tab.Text ([bool]$Ctx.Browse -eq $tab.Browse) $tab.Browse $tab.Glyph
        $chip.Add_MouseLeftButtonUp({ param($s, $e)
            $c = $script:Ctx
            $c.Browse = [bool]$s.Tag
            if (-not $c.Browse) { $c.Home.Nav.Clear() }
            # On vide la recherche en cours pour afficher l'onglet choisi.
            if ($c.Ui.SearchBox.Text) { $c.Ui.SearchBox.Text = '' }
            Render-BtFilters $c
            Render-BtResults $c
        })
        [void]$host_.Children.Add($chip)
    }
}

# --- Rendu de la liste ---------------------------------------------------------
function Render-BtResults {
    param($Ctx)
    $ui = $Ctx.Ui
    if (-not $ui) { return }
    $list = $ui.ResultsPanel
    $list.Children.Clear()
    $s = $Ctx.Search
    $busy = [bool]($s.Pending -or $s.Active)
    $ui.BusyBar.Visibility = if ($busy) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    Update-BtFooter $Ctx

    if (-not $Ctx.Ready -and $Ctx.AuthState -eq 'login') {
        [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE72E) 'Connexion à Confluence requise' $(if ($Ctx.LoginInteractive) { 'Terminez la validation dans la fenêtre de connexion Confluence ; elle se fermera seule une fois connecté.' } else { 'Aucune session SSO ouverte. Cliquez sur « Se connecter » pour ouvrir la page de connexion et faire la validation.' }) $(if ($Ctx.LoginInteractive) { 'Afficher la connexion' } else { 'Se connecter' }) 'login' 'Warn'))
    }
    if (-not $Ctx.Ready -and $Ctx.AuthState -eq 'offline') {
        [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE871) 'Confluence injoignable' 'Le réseau d''entreprise ou le VPN ne semble pas disponible. Nouvelle tentative automatique en cours…' '' '' 'Error'))
    }

    $q = [string]$s.ShownQuery
    if ($q) {
        $an = $s.Analysis
        $copilot = [bool]($Ctx.State.CopilotLicensed -and $Ctx.Config.CopilotAgentUrl)
        $hasSyn = $an -and @($an.Groups | Where-Object { @($_).Count -gt 1 }).Count
        if ($an -and ($an.Natural -or $an.IntentLabel -or $hasSyn -or $copilot)) {
            [void]$list.Children.Add((New-BtUnderstandingCard $Ctx (Get-BtUnderstanding $an ([bool]$s.Relaxed)) $copilot))
        }
        if ($busy -and $s.Fresh) { for ($i = 0; $i -lt 4; $i++) { [void]$list.Children.Add((New-BtSkeletonCard)) }; return }
        if ($s.Error) {
            [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE783) 'La recherche a échoué' $s.Error 'Réessayer' 'retry' 'Error'))
            return
        }
        $res = @($s.Results)
        if (-not $res.Count) {
            $inSpace = $Ctx.Config.SpaceKey -and $Ctx.State.Scope -eq 'space'
            $hint = if ($inSpace) { "Aucune page de l'espace $($Ctx.Config.SpaceKey) ne correspond. Élargissez à tout Biblio-Tech ou essayez d'autres mots-clés." } else { 'Essayez des mots-clés plus courts ou différents.' }
            $act = if ($inSpace) { 'Chercher dans tout Biblio-Tech' } else { '' }
            [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE721) "Aucun résultat pour « $q »" $hint $act 'scopeAll' 'Muted'))
            return
        }
        $hdr = New-BtSectionHeader ('{0} résultat(s)' -f $s.Total) ([string][char]0xE721)
        [void]$list.Children.Add($hdr)
        foreach ($it in $res) { [void]$list.Children.Add((New-BtResultCard $Ctx $it)) }
        if ($s.More) {
            $b = New-Object System.Windows.Controls.Button
            $b.Style = $Ctx.Window.Resources['PrimaryBtn']
            $b.Content = if ($busy) { 'Chargement…' } else { 'Afficher plus de résultats' }
            $b.IsEnabled = -not $busy
            $b.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            $b.Margin = New-BtThickness 0 4 0 10
            $b.Tag = 'more'
            $b.Add_Click({ param($x, $e) Invoke-BtAction $script:Ctx 'more' })
            [void]$list.Children.Add($b)
        }
        return
    }

    # --- Onglet « Catégories » : arborescence ---
    if ($Ctx.Browse) { Render-BtCategTree $Ctx $list; return }

    # --- Accueil en tuiles (lib\BtHome.ps1) : accès rapides, rubriques, épinglés ---
    Render-BtHome $Ctx $list
}

# --- Icône de notification + menu (partagé avec le bouton « … ») --------------
function Initialize-BtTray {
    param($Ctx)
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ico = Get-BtAppIconPath 'ico'
    try { $ni.Icon = if ($ico) { New-Object System.Drawing.Icon $ico, ([System.Windows.Forms.SystemInformation]::SmallIconSize) } else { [System.Drawing.SystemIcons]::Information } } catch { $ni.Icon = [System.Drawing.SystemIcons]::Information }
    $ni.Text = 'Biblio-Tech Widget'
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.ShowImageMargin = $false
    $add = {
        param([string]$Text, [scriptblock]$OnClick)
        $it = New-Object System.Windows.Forms.ToolStripMenuItem $Text
        if ($OnClick) { $it.Add_Click($OnClick) }
        [void]$m.Items.Add($it)
        return $it
    }
    $open = & $add ("Ouvrir Biblio-Tech`t" + $Ctx.Config.Hotkey) { Show-BtSearch $script:Ctx }
    $open.Font = New-Object System.Drawing.Font($open.Font, [System.Drawing.FontStyle]::Bold)
    $null = & $add 'Ouvrir Biblio-Tech dans le navigateur' { Open-BtExternal $script:Ctx.HomeUrl }
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $auto = & $add 'Lancer au démarrage de Windows' { param($s, $e) $s.Checked = Set-BtAutoStart (-not $s.Checked) }
    $auto.Checked = Test-BtAutoStartEnabled
    $cop = & $add 'J''ai une licence Microsoft 365 Copilot' { param($s, $e)
        $script:Ctx.State.CopilotLicensed = -not $script:Ctx.State.CopilotLicensed; Save-BtState $script:Ctx.State; $s.Checked = $script:Ctx.State.CopilotLicensed
        Render-BtResults $script:Ctx }
    $cop.Checked = [bool]$Ctx.State.CopilotLicensed
    if (-not $Ctx.Config.CopilotAgentUrl) { $cop.Enabled = $false; $cop.Text += ' (agent pas encore publié)' }
    $null = & $add 'Mode lecture dans le lecteur' { param($s, $e)
        $script:Ctx.State.ReaderMode = -not $script:Ctx.State.ReaderMode; Save-BtState $script:Ctx.State; $s.Checked = $script:Ctx.State.ReaderMode
        Update-BtReaderMode $script:Ctx }
    $m.Items[$m.Items.Count - 1].Checked = [bool]$Ctx.State.ReaderMode
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = & $add 'Se reconnecter à Confluence' { Invoke-BtReconnect $script:Ctx -ShowWindow }
    $null = & $add 'Rechercher une mise à jour' { Invoke-BtUpdateCheck $script:Ctx -Manual }
    $null = & $add 'Tableau de bord' { Show-BtDashboard $script:Ctx }
    $null = & $add 'Mettre à jour les catégories' { Start-BtCategScan $script:Ctx -Manual }
    $null = & $add 'Reconstruire l''index des catégories (complet)' { Start-BtCategScan $script:Ctx -Manual -Full }
    $null = & $add 'Ouvrir l''analyse des catégories' { Open-BtDataFile $script:Ctx 'analyse-categories.txt' }
    $null = & $add 'Ouvrir le journal des catégories' { Open-BtDataFile $script:Ctx 'categories-journal.log' }
    $null = & $add 'Ouvrir le journal' { try { Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $script:Ctx.DataDir 'app_debug.log') + '"') } catch { } }
    $null = & $add 'Ouvrir le dossier de données' { try { Start-Process explorer.exe -ArgumentList ('"' + $script:Ctx.DataDir + '"') } catch { } }
    $null = & $add ("À propos (v" + $Ctx.Config.Version + ')') { Open-BtExternal ("https://github.com/" + $script:Ctx.Config.GitHubRepo) }
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = & $add 'Quitter' { Stop-BtApp $script:Ctx }
    $ni.ContextMenuStrip = $m
    $ni.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-BtSearch $script:Ctx } })
    $ni.Add_BalloonTipClicked({ Show-BtSearch $script:Ctx })
    $ni.Visible = $true
    $Ctx.Tray = $ni
    $Ctx.TrayMenu = $m
}

# --- Raccourci clavier global (RegisterHotKey via une NativeWindow cachée) ----
if (-not ([System.Management.Automation.PSTypeName]'BtHotkeyWindow').Type) {
    Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class BtHotkeyWindow : NativeWindow, IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    const int WM_HOTKEY = 0x0312;
    const int HK_ID = 0xB17;
    bool _reg;
    public event EventHandler Pressed;
    public BtHotkeyWindow() { CreateHandle(new CreateParams()); }
    public bool Register(uint mods, uint vk) {
        if (_reg) UnregisterHotKey(Handle, HK_ID);
        _reg = RegisterHotKey(Handle, HK_ID, mods | 0x4000, vk);
        return _reg;
    }
    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == HK_ID) {
            EventHandler h = Pressed;
            if (h != null) { try { h(this, EventArgs.Empty); } catch { } }
        }
        base.WndProc(ref m);
    }
    public void Dispose() { if (_reg) { UnregisterHotKey(Handle, HK_ID); _reg = false; } DestroyHandle(); }
}
'@
}

function Initialize-BtHotkey {
    param($Ctx)
    $mods = 0; $vk = 0
    foreach ($p in ([string]$Ctx.Config.Hotkey -split '\+')) {
        switch ($p.Trim().ToLowerInvariant()) {
            'ctrl'  { $mods = $mods -bor 2 }
            'alt'   { $mods = $mods -bor 1 }
            'shift' { $mods = $mods -bor 4 }
            'win'   { $mods = $mods -bor 8 }
            default { try { $vk = [int]([System.Windows.Forms.Keys]$p.Trim()) } catch { } }
        }
    }
    if (-not $vk) { Write-BtLog "[HOTKEY] Raccourci invalide : $($Ctx.Config.Hotkey)"; return }
    try {
        $hk = New-Object BtHotkeyWindow
        $hk.add_Pressed({ Show-BtSearch $script:Ctx })
        if ($hk.Register([uint32]$mods, [uint32]$vk)) { Write-BtLog "[HOTKEY] $($Ctx.Config.Hotkey) actif." }
        else { Write-BtLog "[HOTKEY] $($Ctx.Config.Hotkey) déjà utilisé par une autre application." }
        $Ctx.Hotkey = $hk
    } catch { Write-BtLog "[HOTKEY] Indisponible : $($_.Exception.Message)" }
}
