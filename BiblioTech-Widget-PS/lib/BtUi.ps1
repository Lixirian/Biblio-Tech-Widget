# ============================================================================
#  Fabrique de contrôles WPF : thème, cartes de résultats, puces, sections.
#  Les gestionnaires d'événements lisent leurs données dans .Tag de l'émetteur
#  (pas de GetNewClosure : les fonctions du script restent visibles).
# ============================================================================

$script:BtTheme = @{
    Bar        = '#0B1220'
    Panel      = '#0F172A'
    Card       = '#152038'
    CardHover  = '#1B2947'
    Border     = '#22314F'
    Text       = '#E6EDF7'
    Body       = '#B8C4D8'
    Muted      = '#8193B2'
    Faint      = '#5D6F8F'
    Accent     = '#0088CE'
    AccentSoft = '#1A0088CE'
    Highlight  = '#FFD166'
    HighlightBg = '#26FFD166'
    Ok         = '#22C55E'
    Warn       = '#F59E0B'
    Error      = '#EF4444'
}
$script:BtIconFont = 'Segoe Fluent Icons, Segoe MDL2 Assets'

# Image chargée entièrement en mémoire (CacheOption OnLoad) : aucun verrou ne reste
# sur le fichier, sinon l'updater ne pourrait pas remplacer la copie locale.
function New-BtImageSource {
    param([string]$Path, [int]$DecodeWidth = 0)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $bi = New-Object System.Windows.Media.Imaging.BitmapImage
        $bi.BeginInit()
        $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bi.UriSource = New-Object System.Uri $Path
        if ($DecodeWidth -gt 0) { $bi.DecodePixelWidth = $DecodeWidth }
        $bi.EndInit(); $bi.Freeze()
        return $bi
    } catch { Write-BtLog "[ERREUR UI] Icône illisible : $($_.Exception.Message)"; return $null }
}

$script:BtBrushCache = @{}
function Get-BtBrush {
    param([string]$Hex)
    if ($script:BtTheme.ContainsKey($Hex)) { $Hex = $script:BtTheme[$Hex] }
    if ($script:BtBrushCache.ContainsKey($Hex)) { return $script:BtBrushCache[$Hex] }
    try {
        $b = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex))
        $b.Freeze()
    } catch { $b = [System.Windows.Media.Brushes]::Gray }
    $script:BtBrushCache[$Hex] = $b
    return $b
}

function New-BtThickness { param([double]$L, [double]$T = $L, [double]$R = $L, [double]$B = $T) New-Object System.Windows.Thickness($L, $T, $R, $B) }

function New-BtText {
    param([string]$Text = '', [double]$Size = 12, [string]$Color = 'Text', [switch]$Bold, [switch]$SemiBold, [switch]$Wrap, [switch]$Icon)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = $Size
    $tb.Foreground = Get-BtBrush $Color
    if ($Bold) { $tb.FontWeight = [System.Windows.FontWeights]::Bold }
    elseif ($SemiBold) { $tb.FontWeight = [System.Windows.FontWeights]::SemiBold }
    if ($Wrap) { $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap }
    if ($Icon) { $tb.FontFamily = New-Object System.Windows.Media.FontFamily $script:BtIconFont }
    $tb.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    return $tb
}

# Remplit un TextBlock avec des Run, en surlignant les segments \u0001...\u0002.
function Set-BtHighlightedText {
    param($TextBlock, [string]$Text)
    $TextBlock.Inlines.Clear()
    $hi = $false
    foreach ($seg in [regex]::Split([string]$Text, "([\u0001\u0002])")) {
        if ($seg -eq [string][char]1) { $hi = $true; continue }
        if ($seg -eq [string][char]2) { $hi = $false; continue }
        if (-not $seg) { continue }
        $run = New-Object System.Windows.Documents.Run $seg
        if ($hi) {
            $run.Foreground = Get-BtBrush 'Highlight'
            $run.Background = Get-BtBrush 'HighlightBg'
            $run.FontWeight = [System.Windows.FontWeights]::SemiBold
        }
        $TextBlock.Inlines.Add($run)
    }
}

# Date relative en français (« il y a 3 j ») ; repli sur le libellé Confluence.
function Format-BtDate {
    param([string]$Iso, [string]$Friendly)
    if ($Iso) {
        $d = [datetime]::MinValue
        if ([datetime]::TryParse($Iso, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) {
            $span = (Get-Date) - $d
            if ($span.TotalMinutes -lt 1) { return "à l'instant" }
            if ($span.TotalMinutes -lt 60) { return ('il y a {0} min' -f [int]$span.TotalMinutes) }
            if ($span.TotalHours -lt 24) { return ('il y a {0} h' -f [int]$span.TotalHours) }
            if ($span.TotalDays -lt 7) { return ('il y a {0} j' -f [int]$span.TotalDays) }
            return $d.ToString('dd/MM/yyyy')
        }
    }
    return [string]$Friendly
}

# Pictogramme + couleur selon le type de contenu.
function Get-BtTypeVisual {
    param([string]$Type)
    switch ($Type) {
        'blogpost'   { return @{ Glyph = [string][char]0xE70B; Color = '#A78BFA'; Label = 'Blog' } }
        'attachment' { return @{ Glyph = [string][char]0xE723; Color = '#F59E0B'; Label = 'Pièce jointe' } }
        default      { return @{ Glyph = [string][char]0xE8A5; Color = '#4FB3FF'; Label = 'Page' } }
    }
}

function New-BtIconButton {
    param($Ctx, [string]$Glyph, [string]$ToolTip, $Tag, [double]$Size = 28)
    $b = New-Object System.Windows.Controls.Button
    try { $b.Style = $Ctx.Window.Resources['IconBtn'] } catch { }
    $b.Content = $Glyph
    $b.Width = $Size; $b.Height = $Size; $b.FontSize = 12
    $b.ToolTip = $ToolTip
    $b.Tag = $Tag
    return $b
}

# Puce cliquable (filtres, historique). Tag = données pour le gestionnaire.
function New-BtChip {
    param([string]$Text, [bool]$Active, $Tag, [string]$Glyph = '')
    $chip = New-Object System.Windows.Controls.Border
    $chip.CornerRadius = New-Object System.Windows.CornerRadius 14
    $chip.Padding = New-BtThickness 11 4 11 4
    $chip.Margin = New-BtThickness 0 0 6 6
    $chip.Cursor = [System.Windows.Input.Cursors]::Hand
    $chip.BorderThickness = New-BtThickness 1
    $chip.Tag = $Tag
    if ($Active) { $chip.Background = Get-BtBrush 'Accent'; $chip.BorderBrush = Get-BtBrush 'Accent' }
    else { $chip.Background = Get-BtBrush 'Card'; $chip.BorderBrush = Get-BtBrush 'Border' }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    if ($Glyph) {
        $g = New-BtText -Text $Glyph -Size 10 -Color $(if ($Active) { '#FFFFFF' } else { 'Muted' }) -Icon
        $g.Margin = New-BtThickness 0 0 6 0
        [void]$sp.Children.Add($g)
    }
    [void]$sp.Children.Add((New-BtText -Text $Text -Size 11.5 -Color $(if ($Active) { '#FFFFFF' } else { 'Body' }) -SemiBold:$Active))
    $chip.Child = $sp
    if (-not $Active) {
        $chip.Add_MouseEnter({ param($s, $e) $s.BorderBrush = Get-BtBrush 'Accent' })
        $chip.Add_MouseLeave({ param($s, $e) $s.BorderBrush = Get-BtBrush 'Border' })
    }
    return $chip
}

function New-BtSectionHeader {
    param([string]$Text, [string]$Glyph = '')
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $sp.Margin = New-BtThickness 2 12 0 8
    if ($Glyph) {
        $g = New-BtText -Text $Glyph -Size 11 -Color 'Accent' -Icon
        $g.Margin = New-BtThickness 0 0 7 0
        [void]$sp.Children.Add($g)
    }
    [void]$sp.Children.Add((New-BtText -Text $Text.ToUpperInvariant() -Size 10.5 -Color 'Muted' -Bold))
    return $sp
}

# Carte de résultat : pictogramme | titre surligné, chemin, extrait, méta | actions.
function New-BtResultCard {
    param($Ctx, $Item)
    $vis = Get-BtTypeVisual ([string]$Item.type)
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius 10
    $card.Background = Get-BtBrush 'Card'
    $card.BorderBrush = Get-BtBrush 'Border'
    $card.BorderThickness = New-BtThickness 1
    $card.Padding = New-BtThickness 12 10 8 10
    $card.Margin = New-BtThickness 0 0 0 8
    $card.Cursor = [System.Windows.Input.Cursors]::Hand
    $card.Tag = $Item
    $card.ToolTip = "Clic : ouvrir dans le lecteur   ·   Ctrl+clic : navigateur`n$($Item.url)"

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in @(42, -1, -2)) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        if ($w -gt 0) { $cd.Width = New-Object System.Windows.GridLength $w }
        elseif ($w -eq -1) { $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }
        else { $cd.Width = [System.Windows.GridLength]::Auto }
        $grid.ColumnDefinitions.Add($cd)
    }

    # Pictogramme du type.
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 32; $tile.Height = 32
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 8
    $tile.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
    $tile.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $tileBg = $vis.Color -replace '^#', '#26'
    $tile.Background = Get-BtBrush $tileBg
    $ic = New-BtText -Text $vis.Glyph -Size 15 -Color $vis.Color -Icon
    $ic.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $tile.Child = $ic
    $tile.ToolTip = $vis.Label
    [void]$grid.Children.Add($tile)

    # Contenu.
    $col = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($col, 1)

    $title = New-BtText -Size 14 -SemiBold -Wrap
    $title.MaxHeight = 40
    $title.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    Set-BtHighlightedText $title ([string]$Item.title)
    [void]$col.Children.Add($title)

    $pathParts = @(@([string]$Item.space, [string]$Item.parent) | Where-Object { $_ })
    if ($pathParts.Count) {
        $path = New-BtText -Text ($pathParts -join '  ›  ') -Size 11 -Color 'Muted'
        $path.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        $path.Margin = New-BtThickness 0 2 0 0
        [void]$col.Children.Add($path)
    }

    if ([string]$Item.excerpt) {
        $ex = New-BtText -Size 12.5 -Color 'Body' -Wrap
        $ex.LineHeight = 18
        $ex.MaxHeight = 54
        $ex.TextTrimming = [System.Windows.TextTrimming]::WordEllipsis
        $ex.Margin = New-BtThickness 0 6 0 0
        Set-BtHighlightedText $ex ([string]$Item.excerpt)
        [void]$col.Children.Add($ex)
    }

    # Méta : date · auteur · étiquettes.
    $meta = New-Object System.Windows.Controls.WrapPanel
    $meta.Margin = New-BtThickness 0 7 0 0
    $date = Format-BtDate ([string]$Item.modified) ([string]$Item.friendly)
    if ($date) {
        $ck = New-BtText -Text ([string][char]0xE823) -Size 10 -Color 'Faint' -Icon
        $ck.Margin = New-BtThickness 0 0 5 0
        [void]$meta.Children.Add($ck)
        $dt = New-BtText -Text $date -Size 11 -Color 'Faint'
        $dt.Margin = New-BtThickness 0 0 10 0
        [void]$meta.Children.Add($dt)
    }
    if ([string]$Item.author) {
        $au = New-BtText -Text ([string]$Item.author) -Size 11 -Color 'Faint'
        $au.Margin = New-BtThickness 0 0 10 0
        [void]$meta.Children.Add($au)
    }
    foreach ($l in @($Item.labels | Where-Object { $_ } | Select-Object -First 4)) {
        $lb = New-Object System.Windows.Controls.Border
        $lb.CornerRadius = New-Object System.Windows.CornerRadius 4
        $lb.Background = Get-BtBrush '#1F3355'
        $lb.Padding = New-BtThickness 6 1 6 1
        $lb.Margin = New-BtThickness 0 0 4 2
        $lb.Child = (New-BtText -Text ([string]$l) -Size 10.5 -Color '#9CC3FF')
        [void]$meta.Children.Add($lb)
    }
    if ($meta.Children.Count) { [void]$col.Children.Add($meta) }
    [void]$grid.Children.Add($col)

    # Actions (discrètes, révélées au survol).
    $act = New-Object System.Windows.Controls.StackPanel
    $act.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $act.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
    $act.Margin = New-BtThickness 6 0 0 0
    $act.Opacity = 0.35
    [System.Windows.Controls.Grid]::SetColumn($act, 2)
    $pinned = Test-BtPinned $Ctx.State $Item
    $bPin = New-BtIconButton $Ctx $(if ($pinned) { [string][char]0xE840 } else { [string][char]0xE718 }) $(if ($pinned) { 'Retirer des épinglés' } else { 'Épingler' }) $Item
    if ($pinned) { $bPin.Foreground = Get-BtBrush 'Accent' }
    $bPin.Add_Click({ param($s, $e) Invoke-BtTogglePin $script:Ctx $s.Tag })
    $bCopy = New-BtIconButton $Ctx ([string][char]0xE8C8) 'Copier le lien' $Item
    $bCopy.Add_Click({ param($s, $e) Copy-BtLink $script:Ctx $s.Tag })
    $bWeb = New-BtIconButton $Ctx ([string][char]0xE8A7) 'Ouvrir dans le navigateur' $Item
    $bWeb.Add_Click({ param($s, $e) Open-BtExternal ([string]$s.Tag.url) })
    foreach ($b in @($bPin, $bCopy, $bWeb)) { [void]$act.Children.Add($b) }
    [void]$grid.Children.Add($act)

    $card.Child = $grid
    $card.Add_MouseEnter({ param($s, $e)
        $s.Background = Get-BtBrush 'CardHover'; $s.BorderBrush = Get-BtBrush '#2F5C8A'
        try { $s.Child.Children[2].Opacity = 1 } catch { } })
    $card.Add_MouseLeave({ param($s, $e)
        $s.Background = Get-BtBrush 'Card'; $s.BorderBrush = Get-BtBrush 'Border'
        try { $s.Child.Children[2].Opacity = 0.35 } catch { } })
    $card.Add_MouseLeftButtonUp({ param($s, $e)
        if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) { Open-BtExternal ([string]$s.Tag.url) }
        else { Open-BtReader $script:Ctx $s.Tag }
        Add-BtHistory $script:Ctx.State $script:Ctx.Search.ShownQuery $script:Ctx.Config.HistoryMax
    })
    return $card
}

# Carte « squelette » animée affichée pendant le chargement.
function New-BtSkeletonCard {
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius 10
    $card.Background = Get-BtBrush 'Card'
    $card.Padding = New-BtThickness 12
    $card.Margin = New-BtThickness 0 0 0 8
    $sp = New-Object System.Windows.Controls.StackPanel
    foreach ($w in @(0.55, 0.3, 0.92, 0.75)) {
        $r = New-Object System.Windows.Shapes.Rectangle
        $r.Height = 10; $r.RadiusX = 4; $r.RadiusY = 4
        $r.Fill = Get-BtBrush '#22314F'
        $r.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
        $r.Width = 600 * $w
        $r.Margin = New-BtThickness 0 0 0 8
        [void]$sp.Children.Add($r)
    }
    $card.Child = $sp
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.45, 1.0, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(750))))
    $anim.AutoReverse = $true
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $card.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
    return $card
}

# Bandeau « Compris : … » : ce que l'assistant local a retenu de la demande
# (intention, notions + synonymes, période). Bouton « Demander à Copilot »
# uniquement pour les utilisateurs déclarés licenciés Microsoft 365 Copilot.
function New-BtUnderstandingCard {
    param($Ctx, [string]$Text, [bool]$ShowCopilot)
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius 10
    $card.Background = Get-BtBrush 'AccentSoft'
    $card.BorderBrush = Get-BtBrush '#330088CE'
    $card.BorderThickness = New-BtThickness 1
    $card.Padding = New-BtThickness 12 8 8 8
    $card.Margin = New-BtThickness 0 4 0 6
    $dp = New-Object System.Windows.Controls.DockPanel
    if ($ShowCopilot) {
        $b = New-Object System.Windows.Controls.Button
        try { $b.Style = $Ctx.Window.Resources['PrimaryBtn'] } catch { }
        $b.Content = 'Demander à Copilot ↗'
        $b.Padding = New-BtThickness 12 5 12 5
        $b.Margin = New-BtThickness 10 0 0 0
        $b.ToolTip = 'Ouvre l''agent Copilot Biblio-Tech (votre question est copiée : collez-la avec Ctrl+V)'
        $b.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.DockPanel]::SetDock($b, [System.Windows.Controls.Dock]::Right)
        $b.Add_Click({ param($s, $e) Invoke-BtAction $script:Ctx 'copilot' })
        [void]$dp.Children.Add($b)
    }
    $g = New-BtText -Text ([string][char]0xE945) -Size 14 -Color 'Accent' -Icon
    $g.Margin = New-BtThickness 0 0 9 0
    [System.Windows.Controls.DockPanel]::SetDock($g, [System.Windows.Controls.Dock]::Left)
    [void]$dp.Children.Add($g)
    $t = New-BtText -Size 12 -Color 'Body' -Wrap
    $r1 = New-Object System.Windows.Documents.Run 'Compris : '
    $r1.FontWeight = [System.Windows.FontWeights]::SemiBold
    $r1.Foreground = Get-BtBrush 'Text'
    [void]$t.Inlines.Add($r1)
    [void]$t.Inlines.Add((New-Object System.Windows.Documents.Run $Text))
    [void]$dp.Children.Add($t)
    $card.Child = $dp
    return $card
}

# Carte de message (vide, erreur, connexion requise) avec action optionnelle.
function New-BtMessageCard {
    param($Ctx, [string]$Glyph, [string]$Title, [string]$Text, [string]$Action = '', [string]$ActionTag = '', [string]$Color = 'Accent')
    $card = New-Object System.Windows.Controls.Border
    $card.CornerRadius = New-Object System.Windows.CornerRadius 12
    $card.Background = Get-BtBrush 'Card'
    $card.BorderBrush = Get-BtBrush 'Border'
    $card.BorderThickness = New-BtThickness 1
    $card.Padding = New-BtThickness 22 20 22 20
    $card.Margin = New-BtThickness 0 6 0 8
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $g = New-BtText -Text $Glyph -Size 26 -Color $Color -Icon
    $g.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$sp.Children.Add($g)
    $t = New-BtText -Text $Title -Size 14.5 -SemiBold
    $t.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $t.Margin = New-BtThickness 0 10 0 4
    [void]$sp.Children.Add($t)
    if ($Text) {
        $x = New-BtText -Text $Text -Size 12 -Color 'Muted' -Wrap
        $x.TextAlignment = [System.Windows.TextAlignment]::Center
        $x.MaxWidth = 520
        [void]$sp.Children.Add($x)
    }
    if ($Action) {
        $b = New-Object System.Windows.Controls.Button
        try { $b.Style = $Ctx.Window.Resources['PrimaryBtn'] } catch { }
        $b.Content = $Action
        $b.Tag = $ActionTag
        $b.Margin = New-BtThickness 0 14 0 0
        $b.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $b.Add_Click({ param($s, $e) Invoke-BtAction $script:Ctx ([string]$s.Tag) })
        [void]$sp.Children.Add($b)
    }
    $card.Child = $sp
    return $card
}
