# ============================================================================
#  Navigation : arborescence par catégorie (onglet « Catégories ») et aperçu de
#  l'accueil (fiches les plus commentées + nouvelles fiches des 30 derniers jours).
#  L'arborescence vient de l'index LOCAL des catégories (lib\BtCategories.ps1) :
#  affichage instantané, sans requête. L'aperçu de l'accueil passe par une sonde
#  kick -> poll (même principe que la recherche).
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

# --- Aperçu de l'accueil -------------------------------------------------------------
$script:BtHomeJs = @'
(function(P){
  window.__btHome = {state:'PENDING', id:P.id};
  var t0 = Date.now(), base = P.base;
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function get(u){
    return fetch(base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) { var e = new Error('HTTP 401'); e.auth = true; throw e; }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function all(cql, expand, max){
    var out = [];
    function page(start){
      return get('/rest/api/content/search?cql=' + encodeURIComponent(cql) + '&start=' + start + '&limit=50&expand=' + encodeURIComponent(expand)).then(function(j){
        var res = j.results || []; out = out.concat(res);
        if (res.length && j._links && j._links.next && out.length < max) return page(start + res.length);
        return out;
      });
    }
    return page(0);
  }
  var SP = P.space ? ' AND space = "' + P.space + '"' : '';
  var top = all('type = comment AND created >= now("-' + P.days + 'd")' + SP, 'container,space', 1000).then(function(cs){
    var m = {};
    cs.forEach(function(c){
      var ct = c.container || {}, k = txt(ct.id); if (!k) return;
      if (!m[k]) m[k] = { id:k, type:txt(ct.type || 'page'), title:txt(ct.title), excerpt:'', url: ct._links && ct._links.webui ? base + ct._links.webui : '',
                          space:txt(c.space && c.space.name), spaceKey:txt(c.space && c.space.key), parent:'', modified:'', friendly:'', author:'', labels:[], n:0 };
      m[k].n++;
    });
    return Object.keys(m).map(function(k){ return m[k]; }).sort(function(a, b){ return b.n - a.n; }).slice(0, P.top);
  });
  var fresh = get('/rest/api/content/search?cql=' + encodeURIComponent('type in (page, blogpost) AND created >= now("-' + P.days + 'd")' + SP + ' ORDER BY created DESC')
      + '&limit=' + P.top + '&expand=' + encodeURIComponent('space,history,metadata.labels')).then(function(j){
    return (j.results || []).map(function(c){
      var h = c.history || {}, l = [];
      try { (c.metadata.labels.results || []).forEach(function(x){ l.push(x.name); }); } catch(e){}
      return { id:txt(c.id), type:txt(c.type), title:txt(c.title), excerpt:'', url: c._links && c._links.webui ? base + c._links.webui : '',
               space:txt(c.space && c.space.name), spaceKey:txt(c.space && c.space.key), parent:'', modified:txt(h.createdDate), friendly:'',
               author:txt(h.createdBy && h.createdBy.displayName), labels:l };
    });
  });
  Promise.all([top, fresh]).then(function(r){
    window.__btHome = {state:'OK', id:P.id, top:r[0], fresh:r[1], ms:Date.now()-t0};
  }).catch(function(e){
    window.__btHome = {state: e && e.auth ? 'AUTH' : 'ERROR', id:P.id, error:txt(e && e.message), ms:Date.now()-t0};
  });
  return 'started';
})(__P__)
'@

function Step-BtHome {
    param($Ctx)
    $h = $Ctx.Home
    if ($Ctx.Demo) {
        # Mode démo : aperçu fictif (test de l'interface hors réseau SNCF).
        if (-not $h.At) {
            $h.At = Get-Date
            $h.Top = @((Get-BtDemoResult 'OPW' 0).items | Select-Object -First 3 | ForEach-Object { $_.excerpt = "💬 $(12 - 3 * [int]($_.id) % 7) commentaire(s) ces 30 derniers jours"; $_ })
            $h.Fresh = @((Get-BtDemoResult 'consigne' 6).items | Select-Object -First 3)
            Render-BtResults $Ctx
        }
        return
    }
    if ($h.Probe.Phase -eq '') {
        $due = $Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2 -and (-not $h.At -or ((Get-Date) - $h.At).TotalMinutes -ge 15)
        if ($due -and -not $Ctx.Search.Active) {
            $h.At = Get-Date
            $h.Id = [guid]::NewGuid().ToString('N')
            $p = @{ id = $h.Id; base = $Ctx.Config.BaseUrl.TrimEnd('/'); space = [string]$Ctx.Config.SpaceKey; days = 30; top = 6 } | ConvertTo-Json -Compress
            Start-BtProbe $Ctx $h.Probe ($script:BtHomeJs.Replace('__P__', $p)) 'window.__btHome' 60 $h.Id
        }
        return
    }
    $r = Step-BtProbe $Ctx $h.Probe
    if (-not $r) { return }
    if ($r.state -eq 'OK') {
        $h.Top = @($r.top | Where-Object { $_ } | ForEach-Object { $_.excerpt = "💬 $($_.n) commentaire(s) ces 30 derniers jours"; $_ })
        $h.Fresh = @($r.fresh | Where-Object { $_ })
        $h.Error = $null
        Write-BtLog ("[ACCUEIL] {0} fiche(s) très commentée(s), {1} nouvelle(s) fiche(s) en {2} ms" -f @($h.Top).Count, @($h.Fresh).Count, $r.ms)
    } else {
        $h.Error = [string]$r.error
        $h.At = (Get-Date).AddMinutes(-13)              # nouvel essai dans ~2 min
        Write-BtLog "[ACCUEIL] Échec de l'aperçu ($($r.state) $($r.error))."
    }
    if (-not $Ctx.Search.ShownQuery -and -not $Ctx.Browse) { Render-BtResults $Ctx }
}

# Sections « aperçu » de l'accueil (appelé par Render-BtResults).
function Render-BtHomeOverview {
    param($Ctx, $List)
    $h = $Ctx.Home
    if (-not $Ctx.Ready) { return }
    $sections = @(
        @{ Title = 'Les plus commentées · 30 derniers jours'; Glyph = [string][char]0xE90A; Items = @($h.Top) },
        @{ Title = 'Nouvelles fiches · 30 derniers jours'; Glyph = [string][char]0xE710; Items = @($h.Fresh) }
    )
    foreach ($s in $sections) {
        [void]$List.Children.Add((New-BtSectionHeader $s.Title $s.Glyph))
        if ($s.Items.Count) { foreach ($it in $s.Items) { [void]$List.Children.Add((New-BtResultCard $Ctx $it)) } }
        elseif ($h.Error) { [void]$List.Children.Add((New-BtText -Text "Aperçu indisponible : $($h.Error)" -Size 11.5 -Color 'Muted')) }
        elseif ($h.Probe.Phase -or -not $h.At) { [void]$List.Children.Add((New-BtSkeletonCard)) }
        else { [void]$List.Children.Add((New-BtText -Text 'Rien sur les 30 derniers jours.' -Size 11.5 -Color 'Muted')) }
    }
}
