# ============================================================================
#  Fenêtre principale : XAML (barre haute + panneau déroulant, ou barre latérale),
#  ancrage AppBar, rendu des résultats, filtres, statut, menu, raccourci global.
#  Les deux dispositions exposent les MÊMES noms d'éléments (SearchBox,
#  ResultsPanel, FilterHost, StatusDot...) : le code de rendu est commun.
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

# Bloc logo (réutilisé par les deux dispositions).
$script:BtXamlLogo = @'
<StackPanel Orientation="Horizontal" VerticalAlignment="Center" x:Name="LogoArea" Cursor="Hand" Background="Transparent">
  <Border Width="30" Height="30" CornerRadius="8">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="#0088CE" Offset="0"/>
        <GradientStop Color="#6D5BD0" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <TextBlock Text="&#xE8F1;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
  </Border>
  <StackPanel Margin="9,0,0,0" VerticalAlignment="Center">
    <TextBlock Text="Biblio-Tech" FontSize="14" FontWeight="Bold" Foreground="#E6EDF7"/>
    <TextBlock x:Name="SubTitle" Text="Base de connaissances KM" FontSize="10" Foreground="#8193B2"/>
  </StackPanel>
</StackPanel>
'@

# Champ de recherche (réutilisé).
$script:BtXamlSearch = @'
<Border x:Name="SearchShell" Height="34" CornerRadius="8" Background="#16213A" BorderBrush="#2B3A5C" BorderThickness="1">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="34"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="&#xE721;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Foreground="#8193B2" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <TextBlock x:Name="SearchHint" Grid.Column="1" Text="Rechercher dans la base de connaissances…" Foreground="#5D6F8F" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
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
      <Button x:Name="OpenSpaceBtn" DockPanel.Dock="Right" Style="{StaticResource LinkBtn}" Content="Ouvrir l'espace KM ↗"/>
      <TextBlock x:Name="FooterText" FontSize="11" Foreground="#5D6F8F" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
    </DockPanel>
  </Border>
  <ScrollViewer x:Name="ResultsScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="12,2,8,6">
    <StackPanel x:Name="ResultsPanel"/>
  </ScrollViewer>
</DockPanel>
'@

$script:BtXamlButtons = @'
<StackPanel Orientation="Horizontal" VerticalAlignment="Center">
  <Button x:Name="UpdateBtn" Style="{StaticResource UpdateBtn}" Margin="0,0,8,0" Visibility="Collapsed" ToolTip="Une nouvelle version est disponible : cliquer pour voir les nouveautés"/>
  <Button x:Name="PanelBtn" Style="{StaticResource IconBtn}" Content="&#xE70D;" ToolTip="Afficher / masquer les résultats"/>
  <Button x:Name="PosBtn" Style="{StaticResource IconBtn}" Content="&#xE8AB;" ToolTip="Changer de position (haut / droite / gauche)"/>
  <Button x:Name="MenuBtn" Style="{StaticResource IconBtn}" Content="&#xE712;" ToolTip="Menu"/>
</StackPanel>
'@

function Get-BtWindowXaml {
    param($Ctx)
    $head = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Biblio-Tech" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" ShowInTaskbar="False" Topmost="True" UseLayoutRounding="True" FontFamily="Segoe UI" FontSize="13" TextOptions.TextFormattingMode="Display">'
    if ($Ctx.Mode -eq 'top') {
        $body = @"
<Grid>
  <Grid.RowDefinitions><RowDefinition Height="$($Ctx.Config.BarHeight)"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <Border x:Name="Bar" Background="#0B1220" BorderBrush="#0088CE" BorderThickness="0,0,0,2" Padding="12,0,8,0">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/><ColumnDefinition Width="520"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      $script:BtXamlLogo
      <Grid Grid.Column="1" Margin="22,0,0,0" VerticalAlignment="Center">$script:BtXamlSearch</Grid>
      <Grid Grid.Column="3" Margin="0,0,14,0">$script:BtXamlStatus</Grid>
      <Grid Grid.Column="4">$script:BtXamlButtons</Grid>
    </Grid>
  </Border>
  <Border x:Name="Panel" Grid.Row="1" Width="$($Ctx.Config.PanelWidth)" Height="$($Ctx.Config.PanelHeight)" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="12,6,0,0" CornerRadius="12" Background="#0F172A" BorderBrush="#22314F" BorderThickness="1" Visibility="Collapsed">
    <Border.Effect><DropShadowEffect BlurRadius="22" ShadowDepth="3" Opacity="0.5" Color="#000000"/></Border.Effect>
    $script:BtXamlBody
  </Border>
</Grid>
"@
    } else {
        $bt = if ($Ctx.Mode -eq 'left') { '0,0,2,0' } else { '2,0,0,0' }
        $body = @"
<Border x:Name="Panel" Background="#0F172A" BorderBrush="#0088CE" BorderThickness="$bt">
  <DockPanel>
    <Border x:Name="Bar" DockPanel.Dock="Top" Background="#0B1220" Padding="14,10,8,10">
      <StackPanel>
        <DockPanel>
          <Grid DockPanel.Dock="Right">$script:BtXamlButtons</Grid>
          $script:BtXamlLogo
        </DockPanel>
        <Grid Margin="0,12,6,0">$script:BtXamlSearch</Grid>
        <Grid Margin="2,9,0,0">$script:BtXamlStatus</Grid>
      </StackPanel>
    </Border>
    $script:BtXamlBody
  </DockPanel>
</Border>
"@
    }
    return $head + $script:BtXamlResources + $body + '</Window>'
}

# Construit la fenêtre, collecte les éléments nommés dans $Ctx.Ui et câble les événements.
function New-BtWindow {
    param($Ctx)
    $win = [System.Windows.Markup.XamlReader]::Parse((Get-BtWindowXaml $Ctx))
    $ui = @{ PanelOpen = $false; Suppress = $false }
    foreach ($n in @('Bar', 'Panel', 'LogoArea', 'SubTitle', 'SearchShell', 'SearchHint', 'SearchBox', 'ClearBtn', 'HotkeyText', 'BusyBar',
            'StatusArea', 'StatusDot', 'StatusText', 'FilterHost', 'ResultsScroll', 'ResultsPanel', 'FooterText', 'OpenSpaceBtn',
            'UpdateBtn', 'PanelBtn', 'PosBtn', 'MenuBtn')) {
        $ui[$n] = $win.FindName($n)
    }
    $Ctx.Ui = $ui
    $Ctx.Window = $win
    $ui.HotkeyText.Text = [string]$Ctx.Config.Hotkey
    $ui.SubTitle.Text = if ($Ctx.SpaceName) { $Ctx.SpaceName } else { "Espace $($Ctx.Config.SpaceKey)" }
    $ui.OpenSpaceBtn.Content = "Ouvrir l'espace $($Ctx.Config.SpaceKey) ↗"
    if ($Ctx.Mode -ne 'top') { $ui.PanelBtn.Visibility = [System.Windows.Visibility]::Collapsed }

    $ui.SearchBox.Add_TextChanged({ param($s, $e)
        $u = $script:Ctx.Ui
        $has = [bool]$s.Text
        $u.SearchHint.Visibility = if ($has) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        $u.ClearBtn.Visibility = if ($has) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        if ($u.Suppress) { return }
        $script:Ctx.Search.Typed = $s.Text
        $script:Ctx.Search.DebounceAt = (Get-Date).AddMilliseconds($script:Ctx.Config.SearchDebounceMs)
        Set-BtPanelOpen $script:Ctx $true
    })
    $ui.SearchBox.Add_PreviewKeyDown({ param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $e.Handled = $true
            $script:Ctx.Search.DebounceAt = $null
            Request-BtSearch $script:Ctx $s.Text 0 'search' -Force
            Add-BtHistory $script:Ctx.State $s.Text $script:Ctx.Config.HistoryMax
        } elseif ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $e.Handled = $true
            if ($s.Text) { $s.Text = '' } else { Set-BtPanelOpen $script:Ctx $false }
        }
    })
    $ui.SearchBox.Add_GotKeyboardFocus({ param($s, $e)
        $script:Ctx.Ui.SearchShell.BorderBrush = Get-BtBrush 'Accent'
        Set-BtPanelOpen $script:Ctx $true
    })
    $ui.SearchBox.Add_LostKeyboardFocus({ param($s, $e) $script:Ctx.Ui.SearchShell.BorderBrush = Get-BtBrush '#2B3A5C' })
    $ui.ClearBtn.Add_Click({ $script:Ctx.Ui.SearchBox.Text = ''; $script:Ctx.Ui.SearchBox.Focus() | Out-Null })
    $ui.LogoArea.Add_MouseLeftButtonUp({ Set-BtPanelOpen $script:Ctx (-not $script:Ctx.Ui.PanelOpen) })
    $ui.StatusArea.Add_MouseLeftButtonUp({ if (-not $script:Ctx.Ready) { Show-BtAuthWindow -Force } })
    $ui.PanelBtn.Add_Click({ Set-BtPanelOpen $script:Ctx (-not $script:Ctx.Ui.PanelOpen) })
    $ui.PosBtn.Add_Click({
        $next = switch ($script:Ctx.Mode) { 'top' { 'right' } 'right' { 'left' } default { 'top' } }
        Set-BtMode $script:Ctx $next
    })
    $ui.MenuBtn.Add_Click({ try { $script:Ctx.TrayMenu.Show([System.Windows.Forms.Cursor]::Position) } catch { } })
    $ui.OpenSpaceBtn.Add_Click({ Open-BtExternal $script:Ctx.HomeUrl })
    $ui.UpdateBtn.Add_Click({ Invoke-BtPromptAndUpdate $script:Ctx })

    # Mode haut : le panneau se replie quand on clique ailleurs (comme une liste déroulante).
    $win.Add_Deactivated({ if ($script:Ctx.Mode -eq 'top' -and -not $script:Ctx.Ui.KeepOpen) { Set-BtPanelOpen $script:Ctx $false } })
    $win.Add_Closing({ param($s, $e) if (-not $script:Ctx.Quitting -and $s -eq $script:Ctx.Window) { $e.Cancel = $true } })
    $win.Add_SourceInitialized({ param($s, $e) try { Set-BtDock $script:Ctx } catch { Write-BtLog "[DOCK] $($_.Exception.Message)" } })

    Render-BtFilters $Ctx
    return $win
}

# Bascule le panneau (mode haut : agrandit la fenêtre sous la barre réservée).
function Set-BtPanelOpen {
    param($Ctx, [bool]$Open)
    $ui = $Ctx.Ui
    if (-not $ui) { return }
    if ($Ctx.Mode -ne 'top') { $ui.PanelOpen = $true; return }
    if ($ui.PanelOpen -eq $Open -and $ui.Panel.Visibility -eq $(if ($Open) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed })) { return }
    $ui.PanelOpen = $Open
    $ui.Panel.Visibility = if ($Open) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ui.PanelBtn.Content = if ($Open) { [string][char]0xE70E } else { [string][char]0xE70D }
    $extra = if ($Open) { [double]$Ctx.Config.PanelHeight + 30 } else { 0 }
    try { $Ctx.Window.Height = [double]$Ctx.Config.BarHeight + $extra } catch { }
}

# --- Ancrage AppBar ----------------------------------------------------------
function Get-BtDpi {
    param($Win)
    try {
        $src = [System.Windows.PresentationSource]::FromVisual($Win)
        if ($src -and $src.CompositionTarget) { $m = $src.CompositionTarget.TransformToDevice; return @{ X = $m.M11; Y = $m.M22 } }
    } catch { }
    return @{ X = 1.0; Y = 1.0 }
}

function Set-BtDock {
    param($Ctx)
    $win = $Ctx.Window
    if (-not $win) { return }
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
    if ($hwnd -eq [IntPtr]::Zero) { return }
    if (-not $script:BtAppBarRegistered) { Register-BtAppBar $hwnd | Out-Null }
    $screen = [System.Windows.Forms.Screen]::FromHandle($hwnd)
    if (-not $screen) { $screen = [System.Windows.Forms.Screen]::PrimaryScreen }
    $b = $screen.Bounds
    $wa = $screen.WorkingArea
    $dpi = Get-BtDpi $win
    $mode = $Ctx.Mode
    $thickDip = if ($mode -eq 'top') { $Ctx.Config.BarHeight } else { $Ctx.Config.Thickness }
    $thick = [int][math]::Round($thickDip * $(if ($mode -eq 'top') { $dpi.Y } else { $dpi.X }))
    $g = $null
    switch ($mode) {
        'top'   { $g = Reserve-BtAppBar $hwnd 'top'   $b.Left $b.Top $b.Right ($b.Top + $thick) $thick }
        'left'  { $g = Reserve-BtAppBar $hwnd 'left'  $b.Left $b.Top ($b.Left + $thick) $b.Bottom $thick }
        'right' { $g = Reserve-BtAppBar $hwnd 'right' ($b.Right - $thick) $b.Top $b.Right $b.Bottom $thick }
    }
    if ($g) {
        $win.Left = [double]$g[0] / $dpi.X
        $win.Top = [double]$g[1] / $dpi.Y
        $win.Width = [double]($g[2] - $g[0]) / $dpi.X
        if ($mode -ne 'top') { $win.Height = [double]($g[3] - $g[1]) / $dpi.Y }
    } else {
        # Repli sans AppBar : on colle quand même la fenêtre au bord.
        switch ($mode) {
            'top'   { $win.Left = $b.Left / $dpi.X; $win.Top = $b.Top / $dpi.Y; $win.Width = $b.Width / $dpi.X }
            'left'  { $win.Left = $b.Left / $dpi.X; $win.Top = $wa.Top / $dpi.Y; $win.Width = $Ctx.Config.Thickness; $win.Height = $wa.Height / $dpi.Y }
            'right' { $win.Left = ($b.Right / $dpi.X) - $Ctx.Config.Thickness; $win.Top = $wa.Top / $dpi.Y; $win.Width = $Ctx.Config.Thickness; $win.Height = $wa.Height / $dpi.Y }
        }
    }
    if ($mode -eq 'top') { $o = $Ctx.Ui.PanelOpen; $Ctx.Ui.PanelOpen = -not $o; Set-BtPanelOpen $Ctx $o }
    $Ctx.DockBounds = "$($b.Left),$($b.Top),$($b.Width),$($b.Height)"
}

# Ré-ancrages échelonnés : le shell corrige parfois la 1re réservation au 2e passage.
function Invoke-BtDockSoon {
    foreach ($ms in @(250, 1500)) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromMilliseconds($ms)
        $t.Add_Tick({ param($s, $e) $s.Stop(); try { Set-BtDock $script:Ctx } catch { } })
        $t.Start()
    }
}

# Change de disposition : nouvelle fenêtre, puis fermeture de l'ancienne.
function Set-BtMode {
    param($Ctx, [string]$NewMode)
    if ($NewMode -notin @('top', 'left', 'right') -or $Ctx.Rebuilding) { return }
    $Ctx.Rebuilding = $true
    try {
        $old = $Ctx.Window
        $text = if ($Ctx.Ui) { $Ctx.Ui.SearchBox.Text } else { '' }
        try { if ($old) { Remove-BtAppBar ((New-Object System.Windows.Interop.WindowInteropHelper $old).Handle) } } catch { }
        $Ctx.Mode = $NewMode
        $Ctx.State.Mode = $NewMode
        Save-BtState $Ctx.State
        Show-BtMainWindow $Ctx
        $Ctx.Ui.Suppress = $true
        $Ctx.Ui.SearchBox.Text = $text
        $Ctx.Ui.Suppress = $false
        if ($old -and $old -ne $Ctx.Window) { try { $old.Close() } catch { } }
        Write-BtLog "[UI] Position : $NewMode"
    } finally { $Ctx.Rebuilding = $false }
}

function Show-BtMainWindow {
    param($Ctx)
    $win = New-BtWindow $Ctx
    $win.Show()
    Set-BtStatus $Ctx $Ctx.StatusKind $Ctx.StatusText
    Update-BtUpdateBadge $Ctx
    Render-BtResults $Ctx
    Invoke-BtDockSoon
}

# Ouvre la recherche (raccourci global, icône de notification).
function Show-BtSearch {
    param($Ctx)
    try {
        $w = $Ctx.Window
        if (-not $w.IsVisible) { $w.Show() }
        $w.Activate() | Out-Null
        Set-BtPanelOpen $Ctx $true
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
        'login'   { Show-BtAuthWindow -Force }
        'retry'   { if ($Ctx.Search.ShownQuery) { Request-BtSearch $Ctx $Ctx.Search.ShownQuery 0 'search' -Force } else { Request-BtSearch $Ctx '' 0 'recent' } }
        'scopeAll' { $Ctx.State.Scope = 'all'; Save-BtState $Ctx.State; Render-BtFilters $Ctx; Request-BtSearch $Ctx $Ctx.Search.ShownQuery 0 'search' -Force }
        'more'    { Request-BtSearch $Ctx $Ctx.Search.ShownQuery (@($Ctx.Search.Results).Count) 'search' -Force }
        'clearHistory' { $Ctx.State.History = @(); Save-BtState $Ctx.State; Render-BtResults $Ctx }
    }
}

# --- Filtres -------------------------------------------------------------------
function Render-BtFilters {
    param($Ctx)
    $host_ = $Ctx.Ui.FilterHost
    if (-not $host_) { return }
    $host_.Children.Clear()
    $st = $Ctx.State
    $groups = @(
        @{ Key = 'Scope'; Items = @(@('space', "Espace $($Ctx.Config.SpaceKey)", [string][char]0xE8F1), @('all', 'Tout Confluence', [string][char]0xE774)) },
        @{ Key = 'Type'; Items = @(@('all', 'Tout', ''), @('page', 'Pages', ''), @('blogpost', 'Blogs', ''), @('attachment', 'Pièces jointes', '')) },
        @{ Key = 'Sort'; Items = @(@('relevance', 'Pertinence', ''), @('recent', 'Plus récents', [string][char]0xE823)) }
    )
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
        [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE72E) 'Connexion à Confluence requise' 'La session SSO doit être ouverte une première fois. La fenêtre de connexion Confluence est affichée ; elle se fermera seule une fois connecté.' 'Afficher la connexion' 'login' 'Warn'))
    }
    if (-not $Ctx.Ready -and $Ctx.AuthState -eq 'offline') {
        [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE871) 'Confluence injoignable' 'Le réseau d''entreprise ou le VPN ne semble pas disponible. Nouvelle tentative automatique en cours…' '' '' 'Error'))
    }

    $q = [string]$s.ShownQuery
    if ($q) {
        if ($busy -and $s.Fresh) { for ($i = 0; $i -lt 4; $i++) { [void]$list.Children.Add((New-BtSkeletonCard)) }; return }
        if ($s.Error) {
            [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE783) 'La recherche a échoué' $s.Error 'Réessayer' 'retry' 'Error'))
            return
        }
        $res = @($s.Results)
        if (-not $res.Count) {
            $hint = if ($Ctx.State.Scope -eq 'space') { "Aucune page de l'espace $($Ctx.Config.SpaceKey) ne correspond. Élargissez à tout Confluence ou essayez d'autres mots-clés." } else { 'Essayez des mots-clés plus courts ou différents.' }
            $act = if ($Ctx.State.Scope -eq 'space') { 'Chercher dans tout Confluence' } else { '' }
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

    # --- Accueil : épinglés, recherches récentes, mises à jour de l'espace ---
    $pins = @($Ctx.State.Pins)
    if ($pins.Count) {
        [void]$list.Children.Add((New-BtSectionHeader 'Épinglés' ([string][char]0xE840)))
        foreach ($p in $pins) {
            $it = [pscustomobject]@{ id = $p.id; type = $p.type; title = $p.title; excerpt = ''; url = $p.url; space = $p.space; parent = ''; modified = ''; friendly = ''; author = ''; labels = @() }
            [void]$list.Children.Add((New-BtResultCard $Ctx $it))
        }
    }
    $hist = @($Ctx.State.History)
    if ($hist.Count) {
        $h = New-BtSectionHeader 'Recherches récentes' ([string][char]0xE81C)
        $clr = New-Object System.Windows.Controls.Button
        $clr.Style = $Ctx.Window.Resources['LinkBtn']
        $clr.Content = 'Effacer'
        $clr.Margin = New-BtThickness 8 -3 0 0
        $clr.Add_Click({ Invoke-BtAction $script:Ctx 'clearHistory' })
        [void]$h.Children.Add($clr)
        [void]$list.Children.Add($h)
        $wp = New-Object System.Windows.Controls.WrapPanel
        foreach ($hq in ($hist | Select-Object -First 10)) {
            $chip = New-BtChip $hq $false $hq ([string][char]0xE81C)
            $chip.Add_MouseLeftButtonUp({ param($x, $e)
                $script:Ctx.Ui.SearchBox.Text = [string]$x.Tag
                $script:Ctx.Ui.SearchBox.CaretIndex = $script:Ctx.Ui.SearchBox.Text.Length
                $script:Ctx.Search.DebounceAt = $null
                Request-BtSearch $script:Ctx ([string]$x.Tag) 0 'search' -Force
            })
            [void]$wp.Children.Add($chip)
        }
        [void]$list.Children.Add($wp)
    }
    $label = if ($Ctx.SpaceName) { "Mis à jour récemment · $($Ctx.SpaceName)" } else { "Mis à jour récemment · $($Ctx.Config.SpaceKey)" }
    [void]$list.Children.Add((New-BtSectionHeader $label ([string][char]0xE823)))
    if ($s.RecentError) {
        [void]$list.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE783) 'Chargement impossible' $s.RecentError 'Réessayer' 'retry' 'Error'))
    } elseif (@($s.Recent).Count) {
        foreach ($it in @($s.Recent)) { [void]$list.Children.Add((New-BtResultCard $Ctx $it)) }
    } elseif ($Ctx.Ready -or $busy) {
        for ($i = 0; $i -lt 3; $i++) { [void]$list.Children.Add((New-BtSkeletonCard)) }
    }
}

# --- Icône de notification + menu (partagé avec le bouton « … ») --------------
function Initialize-BtTray {
    param($Ctx)
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ico = Get-BtAppIconPath 'ico'
    try { $ni.Icon = if ($ico) { New-Object System.Drawing.Icon $ico } else { [System.Drawing.SystemIcons]::Information } } catch { $ni.Icon = [System.Drawing.SystemIcons]::Information }
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
    $null = & $add ("Rechercher`t" + $Ctx.Config.Hotkey) { Show-BtSearch $script:Ctx }
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $pos = New-Object System.Windows.Forms.ToolStripMenuItem 'Position'
    foreach ($p in @(@('top', 'En haut'), @('right', 'À droite'), @('left', 'À gauche'))) {
        $pi = New-Object System.Windows.Forms.ToolStripMenuItem $p[1]
        $pi.Tag = $p[0]
        $pi.Add_Click({ param($s, $e) Set-BtMode $script:Ctx ([string]$s.Tag) })
        [void]$pos.DropDownItems.Add($pi)
    }
    [void]$m.Items.Add($pos)
    $auto = & $add 'Lancer au démarrage de Windows' { param($s, $e) $s.Checked = Set-BtAutoStart (-not $s.Checked) }
    $auto.Checked = Test-BtAutoStartEnabled
    $null = & $add 'Mode lecture dans le lecteur' { param($s, $e)
        $script:Ctx.State.ReaderMode = -not $script:Ctx.State.ReaderMode; Save-BtState $script:Ctx.State; $s.Checked = $script:Ctx.State.ReaderMode
        Update-BtReaderMode $script:Ctx }
    $m.Items[$m.Items.Count - 1].Checked = [bool]$Ctx.State.ReaderMode
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = & $add 'Se reconnecter à Confluence' { Invoke-BtReconnect $script:Ctx -ShowWindow }
    $null = & $add 'Rechercher une mise à jour' { Invoke-BtUpdateCheck $script:Ctx -Manual }
    $null = & $add 'Ouvrir le journal' { try { Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $script:Ctx.DataDir 'app_debug.log') + '"') } catch { } }
    $null = & $add 'Ouvrir le dossier de données' { try { Start-Process explorer.exe -ArgumentList ('"' + $script:Ctx.DataDir + '"') } catch { } }
    $null = & $add ("À propos (v" + $Ctx.Config.Version + ')') { Open-BtExternal ("https://github.com/" + $script:Ctx.Config.GitHubRepo) }
    [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = & $add 'Quitter' { Stop-BtApp $script:Ctx }
    $ni.ContextMenuStrip = $m
    $ni.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-BtSearch $script:Ctx } })
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
