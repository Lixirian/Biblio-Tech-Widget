# ============================================================================
#  Navigation : arborescence par catégorie (onglet « Catégories »).
#  L'arborescence vient de l'index LOCAL des catégories (lib\BtCategories.ps1) :
#  affichage instantané, sans requête. (L'accueil en tuiles : lib\BtHome.ps1.)
# ============================================================================

# --- Arborescence ------------------------------------------------------------------
function New-BtTreeRow {
    param($Ctx, [int]$Depth, [string]$Glyph, [string]$Text, [string]$Count, $Tag, [bool]$IsNode, $OpenItem)
    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = New-Object System.Windows.CornerRadius 6
    $row.Padding = New-BtThickness 8 5 6 5
    $row.Margin = New-BtThickness (4 + 18 * $Depth) 1 4 1
    $row.Background = if ($IsNode -and $Depth -eq 0) { Get-BtBrush 'Card' } else { [System.Windows.Media.Brushes]::Transparent }
    $row.Cursor = [System.Windows.Input.Cursors]::Hand
    $row.Tag = $Tag
    $g = New-Object System.Windows.Controls.Grid
    foreach ($w in @('Auto', '*', 'Auto', 'Auto')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        [void]$g.ColumnDefinitions.Add($cd)
    }
    $ic = New-BtText -Text $Glyph -Size $(if ($IsNode) { 10 } else { 12 }) -Color $(if ($IsNode) { 'Accent' } else { 'Muted' }) -Icon
    $ic.Margin = New-BtThickness 0 2 8 0
    [void]$g.Children.Add($ic)
    $tb = New-BtText -Text $Text -Size $(if ($IsNode -and $Depth -eq 0) { 13 } else { 12.5 }) -Color 'Body' -SemiBold:($IsNode)
    $tb.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $tb.ToolTip = $Text
    [System.Windows.Controls.Grid]::SetColumn($tb, 1); [void]$g.Children.Add($tb)
    if ($Count) {
        $cn = New-BtText -Text $Count -Size 11 -Color 'Muted'
        $cn.Margin = New-BtThickness 8 1 4 0
        [System.Windows.Controls.Grid]::SetColumn($cn, 2); [void]$g.Children.Add($cn)
    }
    if ($OpenItem) {
        # Page de rubrique elle-même : bouton « ouvrir » à droite du nœud.
        $ob = New-Object System.Windows.Controls.Button
        $ob.Style = $Ctx.Window.Resources['LinkBtn']
        $ob.Content = 'ouvrir ↗'
        $ob.Margin = New-BtThickness 6 -1 0 0
        $ob.Tag = $OpenItem
        $ob.Add_Click({ param($s, $e) $e.Handled = $true; Open-BtReader $script:Ctx $s.Tag })
        [System.Windows.Controls.Grid]::SetColumn($ob, 3); [void]$g.Children.Add($ob)
    }
    $row.Child = $g
    $row.Add_MouseEnter({ param($s, $e) if ($s.Background -eq [System.Windows.Media.Brushes]::Transparent) { $s.Background = Get-BtBrush 'CardHover' } })
    $row.Add_MouseLeave({ param($s, $e) if ($s.Background -ne (Get-BtBrush 'Card')) { $s.Background = [System.Windows.Media.Brushes]::Transparent } })
    return $row
}

# Fiche de l'index -> objet attendu par le lecteur / les cartes.
function ConvertTo-BtBrowseItem {
    param($Ctx, [string]$Id, $It)
    $u = [string]$It['u']
    $url = if ($u -match '^https?://') { $u } elseif ($u) { $Ctx.Config.BaseUrl.TrimEnd('/') + $u } else { $Ctx.Config.BaseUrl.TrimEnd('/') + '/pages/viewpage.action?pageId=' + $Id }
    $a = @($It['a'])
    return [pscustomobject]@{ id = $Id; type = [string]$It['ty']; title = [string]$It['t']; excerpt = ''; url = $url; space = [string]$It['s']
        parent = $(if ($a.Count) { [string]$a[$a.Count - 1] } else { '' }); modified = [string]$It['m']; friendly = ''; author = ''; labels = @($It['l']) }
}

function Render-BtCategTree {
    param($Ctx, $List)
    $tree = Get-BtCategTree $Ctx
    $hdr = New-BtSectionHeader $(if ($tree) { "Catégories · $($tree.N) fiche(s)" } else { 'Catégories' }) ([string][char]0xE8B7)
    $upd = New-Object System.Windows.Controls.Button
    $upd.Style = $Ctx.Window.Resources['LinkBtn']
    $upd.Content = if ($Ctx.Categ.Probe.Phase) { 'Mise à jour en cours…' } else { 'Mettre à jour' }
    $upd.IsEnabled = -not $Ctx.Categ.Probe.Phase
    $upd.Margin = New-BtThickness 10 -3 0 0
    $upd.Add_Click({ Start-BtCategScan $script:Ctx -Manual; Render-BtResults $script:Ctx })
    [void]$hdr.Children.Add($upd)
    [void]$List.Children.Add($hdr)
    if (-not $tree) {
        $msg = if ($Ctx.Categ.Probe.Phase) { 'Construction de l''index des catégories en cours (quelques minutes au premier lancement, puis quelques secondes à chaque ouverture)…' }
               elseif (-not $Ctx.Ready) { 'Connexion à Confluence requise pour construire l''index des catégories.' }
               else { 'L''index des catégories sera construit automatiquement dans quelques instants.' }
        [void]$List.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE8B7) 'Arborescence en préparation' $msg '' '' 'Muted'))
        return
    }
    $open = $Ctx.BrowseOpen
    $render = $null
    $render = {
        param($node, [int]$depth)
        foreach ($k in @($node.Kids.Values | Sort-Object { $_.Name })) {
            $isOpen = [bool]$open[$k.Path]
            $glyph = if ($isOpen) { [string][char]0xE70D } else { [string][char]0xE76C }      # chevron bas / droite
            $self = if ($k.Self) { ConvertTo-BtBrowseItem $Ctx ([string]$k.Self.id) $k.Self.it } else { $null }
            $row = New-BtTreeRow $Ctx $depth $glyph $k.Name ([string]$k.N) $k.Path $true $self
            $row.Add_MouseLeftButtonUp({ param($s, $e)
                $o = $script:Ctx.BrowseOpen
                if ($o[$s.Tag]) { $o.Remove($s.Tag) } else { $o[$s.Tag] = $true }
                Render-BtResults $script:Ctx })
            [void]$List.Children.Add($row)
            if ($isOpen) { & $render $k ($depth + 1) }
        }
        $pages = @($node.Pages | Sort-Object { [string]$_.it['t'] })
        $max = 200
        foreach ($p in ($pages | Select-Object -First $max)) {
            $item = ConvertTo-BtBrowseItem $Ctx ([string]$p.id) $p.it
            $vis = Get-BtTypeVisual $item.type
            $row = New-BtTreeRow $Ctx $depth ([string]$vis.Glyph) $item.title '' $item $false $null
            $row.Add_MouseLeftButtonUp({ param($s, $e)
                if ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) { Open-BtExternal $s.Tag.url } else { Open-BtReader $script:Ctx $s.Tag } })
            [void]$List.Children.Add($row)
        }
        if ($pages.Count -gt $max) {
            $more = New-BtText -Text "… et $($pages.Count - $max) autre(s) fiche(s) : utilisez la recherche." -Size 11.5 -Color 'Muted'
            $more.Margin = New-BtThickness (12 + 18 * $depth) 4 0 6
            [void]$List.Children.Add($more)
        }
    }
    & $render $tree 0
}
