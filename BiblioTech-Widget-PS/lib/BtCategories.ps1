# ============================================================================
#  Catégories (LOCAL uniquement : rien n'est envoyé ailleurs).
#  Index des MÉTADONNÉES des fiches Confluence (titre, pages parentes, étiquettes,
#  espace, type, lien, date de modification) — jamais le contenu — tenu à jour de
#  façon INCRÉMENTALE à chaque ouverture :
#    - 1er passage (ou index > 7 jours, ou demande « Reconstruire ») : parcours complet ;
#    - sinon : fiches modifiées depuis la dernière analyse + liste légère des
#      identifiants (détection des fiches supprimées).
#  Chaque passage ajoute au journal categories-journal.log les catégories ajoutées /
#  retirées / modifiées et les fiches ajoutées / supprimées / déplacées, puis régénère
#  le rapport analyse-categories.txt. L'index alimente l'arborescence « Catégories ».
#  Catégorie = page parente de niveau 1 (sous l'accueil de l'espace), sous-catégorie =
#  niveau 2.
# ============================================================================

$script:BtCategJs = @'
(function(P){
  window.__btInv = {state:'PENDING', id:P.id, done:0};
  var t0 = Date.now(), items = [], ids = [], spaces = [], total = -1, idsComplete = true;
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function get(u){
    return fetch(P.base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) throw new Error('HTTP 401 (session expirée)');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  // Métadonnées complètes (fiches nouvelles / modifiées, ou tout l'espace en mode complet).
  function page(cql, start){
    var q = 'cql=' + encodeURIComponent(cql) + '&start=' + start + '&limit=50&expand=' + encodeURIComponent('ancestors,metadata.labels,space,version');
    return get('/rest/api/content/search?' + q).then(function(j){
      if (typeof j.totalSize === 'number' && start === 0) total = j.totalSize;
      var res = j.results || [];
      res.forEach(function(c){
        var a = [], l = [];
        try { (c.ancestors || []).forEach(function(x){ a.push(txt(x.title)); }); } catch(e){}
        try { (c.metadata.labels.results || []).forEach(function(x){ l.push(txt(x.name)); }); } catch(e){}
        items.push({id:txt(c.id), t:txt(c.title), ty:txt(c.type), s:txt(c.space && c.space.key), a:a, l:l,
                    u:txt(c._links && c._links.webui), m:txt(c.version && c.version.when)});
      });
      window.__btInv = {state:'PENDING', id:P.id, done:items.length};
      if (res.length && j._links && j._links.next && items.length < P.max) return page(cql, start + res.length);
    });
  }
  // Identifiants seuls (léger) : pour repérer les fiches supprimées.
  function idPage(start){
    return get('/rest/api/content/search?cql=' + encodeURIComponent(P.cql) + '&start=' + start + '&limit=200').then(function(j){
      var res = j.results || [];
      res.forEach(function(c){ ids.push(txt(c.id)); });
      if (res.length && j._links && j._links.next) {
        if (ids.length >= P.max * 2) { idsComplete = false; return; }
        return idPage(start + res.length);
      }
    });
  }
  var chain;
  if (P.mode === 'full') {
    chain = get('/rest/api/space?limit=200').then(function(j){
      (j.results || []).forEach(function(s){ spaces.push({k:txt(s.key), n:txt(s.name), ty:txt(s.type)}); });
    }).catch(function(){}).then(function(){ return page(P.cql, 0); });
  } else {
    chain = page(P.cql + ' AND lastmodified >= "' + P.since + '"', 0).then(function(){ return idPage(0); });
  }
  chain.then(function(){
    window.__btInv = {state:'OK', id:P.id, mode:P.mode, items:items, ids:ids, idsComplete:idsComplete, spaces:spaces, total:total,
                      truncated:(P.mode === 'full' && items.length >= P.max), ms:Date.now()-t0};
  }).catch(function(e){
    window.__btInv = {state:'ERROR', id:P.id, mode:P.mode, error:txt(e && e.message), items:items, ids:[], idsComplete:false, spaces:spaces, total:total, ms:Date.now()-t0};
  });
  return 'started';
})(__P__)
'@

# Le sondage ne renvoie qu'un petit objet tant que l'analyse tourne (pas la liste entière).
$script:BtCategPollJs = "(window.__btInv && window.__btInv.state === 'PENDING') ? {state:'PENDING', id:window.__btInv.id} : window.__btInv"

# --- Index local (sérialiseur .NET : nettement plus rapide que ConvertTo-Json en PS 5.1) ---
function Get-BtJsonSerializer {
    Add-Type -AssemblyName System.Web.Extensions
    $js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $js.MaxJsonLength = [int]::MaxValue
    return $js
}

function Get-BtCategIndexPath { param($Ctx) Join-Path $Ctx.DataDir 'categories-index.json' }

# Index : @{ LastScan; LastFull; Spaces; Items = @{ id = @{ t; ty; s; a; l; u; m } } }
function Read-BtCategIndex {
    param($Ctx)
    if ($Ctx.Categ.Index) { return $Ctx.Categ.Index }
    $p = Get-BtCategIndexPath $Ctx
    $idx = $null
    if (Test-Path -LiteralPath $p) {
        try {
            $d = (Get-BtJsonSerializer).DeserializeObject([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8))
            $items = @{}
            foreach ($k in $d['Items'].Keys) { $items[$k] = $d['Items'][$k] }
            $idx = @{ LastScan = [string]$d['LastScan']; LastFull = [string]$d['LastFull']; Spaces = @($d['Spaces']); Items = $items }
        } catch { Write-BtLog "[CATEG] Index illisible, reconstruction complète ($($_.Exception.Message))." }
    }
    $Ctx.Categ.Index = $idx
    return $idx
}

function Save-BtCategIndex {
    param($Ctx, $Idx)
    try {
        $json = (Get-BtJsonSerializer).Serialize(@{ LastScan = $Idx.LastScan; LastFull = $Idx.LastFull; Spaces = $Idx.Spaces; Items = $Idx.Items })
        $p = Get-BtCategIndexPath $Ctx
        [IO.File]::WriteAllText($p + '.tmp', $json, (New-Object System.Text.UTF8Encoding $false))
        Move-Item -LiteralPath ($p + '.tmp') -Destination $p -Force
    } catch { Write-BtLog "[CATEG] Sauvegarde de l'index KO : $($_.Exception.Message)" }
}

# Catégorie (niveau 1) et sous-catégorie (niveau 2) d'une fiche ; a[0] = accueil de l'espace.
function Get-BtCategOf {
    param($It)
    $a = @($It['a'])
    if ($a.Count -ge 2) { return @{ Cat = [string]$a[1]; Sub = $(if ($a.Count -ge 3) { [string]$a[2] } else { '' }) } }
    if ($a.Count -eq 1) { return @{ Cat = [string]$It['t']; Sub = '' } }     # rubrique de 1er niveau
    return @{ Cat = '(accueil)'; Sub = '' }
}

# --- Lancement / pompe -----------------------------------------------------------
function Start-BtCategScan {
    param($Ctx, [switch]$Manual, [switch]$Full)
    $c = $Ctx.Categ
    if ($c.Probe.Phase -ne '' -or $c.Job) { if ($Manual) { Show-BtFlash $Ctx 'Analyse des catégories déjà en cours…' }; return }
    if (-not ($Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2)) {
        if ($Manual) { Show-BtFlash $Ctx 'Connexion à Confluence requise pour analyser les catégories.' }
        return
    }
    $idx = Read-BtCategIndex $Ctx
    $mode = 'inc'
    $lastFull = [datetime]::MinValue
    if ($idx) { [void][datetime]::TryParse([string]$idx.LastFull, [ref]$lastFull) }
    if ($Full -or -not $idx -or -not $idx.LastScan -or ((Get-Date) - $lastFull).TotalDays -ge 7) { $mode = 'full' }
    $since = ''
    if ($mode -eq 'inc') { $since = ([datetime]::Parse($idx.LastScan)).AddDays(-1).ToString('yyyy-MM-dd') }   # marge d'un jour
    $cql = 'type in (page, blogpost)'
    if ($Ctx.Config.SpaceKey) { $cql = ('space = "{0}" AND ' -f (ConvertTo-BtCqlString $Ctx.Config.SpaceKey)) + $cql }
    $c.Id = [guid]::NewGuid().ToString('N')
    $c.Manual = [bool]$Manual
    $c.Mode = $mode
    $c.StartedAt = Get-Date
    $p = @{ id = $c.Id; base = $Ctx.Config.BaseUrl.TrimEnd('/'); cql = $cql; max = [int]$Ctx.Config.CategScanMax; mode = $mode; since = $since } | ConvertTo-Json -Compress
    Write-BtLog ("[CATEG] Analyse des catégories : {0}{1}." -f $(if ($mode -eq 'full') { 'parcours complet' } else { 'mise à jour incrémentale' }), $(if ($since) { " (fiches modifiées depuis le $since)" } else { '' }))
    if ($Manual) { Show-BtFlash $Ctx $(if ($mode -eq 'full') { 'Analyse complète des catégories en cours (quelques minutes)…' } else { 'Mise à jour des catégories en cours…' }) }
    Start-BtProbe $Ctx $c.Probe ($script:BtCategJs.Replace('__P__', $p)) $script:BtCategPollJs 900 $c.Id
}

# Fonctions copiées dans les tâches de fond (index, fusion, journal, rapport, arborescence).
$script:BtCategFns = @('Get-BtJsonSerializer', 'Get-BtCategIndexPath', 'Read-BtCategIndex', 'Save-BtCategIndex', 'Get-BtCategOf',
    'Convert-BtCategItem', 'Write-BtCategJournal', 'Format-BtCategReport', 'Get-BtCategTree', 'Invoke-BtCategMerge')

# Contexte minimal (données seulement) transmis à une tâche de fond.
function New-BtCategBgCtx {
    param($Ctx)
    return @{ DataDir = $Ctx.DataDir; Config = $Ctx.Config; Categ = @{ Index = $Ctx.Categ.Index; Tree = $null } }
}

function Step-BtCategScan {
    param($Ctx)
    $c = $Ctx.Categ
    # Tâche de fond en cours (chargement de l'index au démarrage, ou fusion d'une analyse).
    if ($c.Job) {
        if (-not (Test-BtBgJobDone $c.Job)) { return }
        $job = $c.Job; $c.Job = $null
        $o = Receive-BtBgJob $job
        $c.Loaded = $true
        if (-not $o.Error -and $o.Result) {
            $c.Index = $o.Result.Idx
            $c.Tree = $o.Result.Tree
            if ($Ctx.Browse -and -not $Ctx.Search.ShownQuery) { Render-BtResults $Ctx }
        }
        if ($job.Name -eq 'catégories (fusion)' -and $c.Manual) { try { Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $Ctx.DataDir 'categories-journal.log') + '"') } catch { } }
        return
    }
    # Index lu (gros fichier JSON) et arborescence construite hors de la fenêtre, une fois.
    if (-not $c.Loaded -and -not $c.Index) {
        $c.Job = Start-BtBgJob 'catégories (chargement)' $script:BtCategFns { param($C) $i = Read-BtCategIndex $C; @{ Idx = $i; Tree = $(if ($i) { Get-BtCategTree $C } else { $null }) } } @(, (New-BtCategBgCtx $Ctx))
        return
    }
    if ($c.Probe.Phase -eq '') {
        # Automatique à CHAQUE ouverture, un peu après la connexion (laisse passer la 1re recherche).
        if ($Ctx.Ready -and -not $Ctx.Demo -and $c.AutoAt -and (Get-Date) -ge $c.AutoAt) {
            $c.AutoAt = $null
            Start-BtCategScan $Ctx
        }
        return
    }
    $r = Step-BtProbe $Ctx $c.Probe
    if ($r) { Complete-BtCategScan $Ctx $r }
}

# Réponse de l'analyse (sonde en mode brut : {state; id; raw}). Le décodage du JSON
# (plusieurs Mo), la fusion, le journal, le rapport et l'arborescence partent en tâche de fond.
function Complete-BtCategScan {
    param($Ctx, $R)
    $c = $Ctx.Categ
    if ($R.state -ne 'OK') {
        $err = [string]$R.error
        if (-not $err -and $R.raw) { $m = [regex]::Match([string]$R.raw, '"error":"((?:[^"\\]|\\.)*)"'); if ($m.Success) { $err = $m.Groups[1].Value } }
        Write-BtLog "[CATEG] Échec de l'analyse ($($R.state) $err) : index inchangé."
        if ($c.Manual) { Show-BtFlash $Ctx "Analyse des catégories impossible : $err" }
        return
    }
    Write-BtLog ("[CATEG] Réponse reçue ({0} Ko) : traitement en arrière-plan." -f [int](([string]$R.raw).Length / 1024))
    $c.Job = Start-BtBgJob 'catégories (fusion)' $script:BtCategFns { param($C, $Raw) Invoke-BtCategMerge $C $Raw } @((New-BtCategBgCtx $Ctx), [string]$R.raw)
}

# Exécuté en TÂCHE DE FOND : aucune interface ici. Renvoie @{ Idx; Tree }.
function Invoke-BtCategMerge {
    param($Ctx, [string]$Raw)
    $c = $Ctx.Categ
    $R = (Get-BtJsonSerializer).DeserializeObject($Raw)
    $new = @($R['items'] | Where-Object { $_ })
    $old = Read-BtCategIndex $Ctx
    $oldItems = if ($old) { $old.Items } else { @{} }
    $items = @{}
    if ($R.mode -eq 'full') {
        foreach ($it in $new) { $items[[string]$it.id] = Convert-BtCategItem $it }
    } else {
        foreach ($k in $oldItems.Keys) { $items[$k] = $oldItems[$k] }
        foreach ($it in $new) { $items[[string]$it.id] = Convert-BtCategItem $it }
        # Suppressions : seulement si la liste des identifiants est complète.
        if ($R.idsComplete -and @($R.ids).Count) {
            $alive = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($i in @($R.ids)) { [void]$alive.Add([string]$i) }
            foreach ($k in @($items.Keys)) { if (-not $alive.Contains($k)) { $items.Remove($k) } }
        }
    }
    $now = (Get-Date).ToString('s')
    $idx = @{ LastScan = $now; LastFull = $(if ($R.mode -eq 'full' -or -not $old) { $now } else { $old.LastFull })
              Spaces = $(if ($R.mode -eq 'full' -or -not $old) { @($R.spaces | ForEach-Object { @{ k = [string]$_.k; n = [string]$_.n; ty = [string]$_.ty } }) } else { $old.Spaces })
              Items = $items }
    $changes = Write-BtCategJournal $Ctx $oldItems $items ([bool]$old) $R.mode
    Save-BtCategIndex $Ctx $idx
    $c.Index = $idx
    $c.Tree = $null                          # arborescence à reconstruire (ci-dessous)
    # Rapport de synthèse régénéré depuis l'index.
    $path = Join-Path $Ctx.DataDir 'analyse-categories.txt'
    try {
        $list = @($items.Values | ForEach-Object { [pscustomobject]@{ t = [string]$_['t']; ty = [string]$_['ty']; s = [string]$_['s']; a = @($_['a']); l = @($_['l']) } })
        $meta = [pscustomobject]@{ spaces = @($idx.Spaces | ForEach-Object { [pscustomobject]@{ k = $_['k']; n = $_['n'] } }); total = $items.Count; truncated = [bool]$R.truncated; ms = $R.ms }
        [IO.File]::WriteAllText($path, (Format-BtCategReport $Ctx $meta $list), (New-Object System.Text.UTF8Encoding $true))
    } catch { Write-BtLog "[CATEG] Écriture du rapport KO : $($_.Exception.Message)" }
    Write-BtLog ("[CATEG] {0} : {1} fiche(s) dans l'index ({2} lue(s) en {3} s) ; {4}" -f $(if ($R.mode -eq 'full') { 'Analyse complète' } else { 'Mise à jour' }), $items.Count, $new.Count, [int]($R.ms / 1000), $changes)
    if ($R.truncated) { Write-BtLog "[CATEG] Limite CategScanMax ($($Ctx.Config.CategScanMax)) atteinte : index partiel." }
    return @{ Idx = $idx; Tree = (Get-BtCategTree $Ctx) }
}

function Convert-BtCategItem {
    param($It)
    return @{ t = [string]$It.t; ty = [string]$It.ty; s = [string]$It.s; a = @($It.a | ForEach-Object { [string]$_ }); l = @($It.l | ForEach-Object { [string]$_ }); u = [string]$It.u; m = [string]$It.m }
}

# Journal des changements (catégories puis fiches). Renvoie un résumé d'une ligne.
function Write-BtCategJournal {
    param($Ctx, $Old, $New, [bool]$HadIndex, [string]$Mode)
    $lines = New-Object System.Collections.Generic.List[string]
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $count = {
        param($items)
        $m = @{}
        foreach ($v in $items.Values) { $k = (Get-BtCategOf $v).Cat; if ($m.ContainsKey($k)) { $m[$k]++ } else { $m[$k] = 1 } }
        return $m
    }
    $co = & $count $Old; $cn = & $count $New
    $catAdd = 0; $catDel = 0; $catMod = 0
    foreach ($k in ($cn.Keys | Sort-Object)) {
        if (-not $co.ContainsKey($k)) { if ($HadIndex) { $lines.Add("  + catégorie « $k » ($($cn[$k]) fiche(s))"); $catAdd++ } }
        elseif ($co[$k] -ne $cn[$k]) { $d = $cn[$k] - $co[$k]; $lines.Add(("  ~ catégorie « {0} » : {1} -> {2} fiche(s) ({3:+0;-0})" -f $k, $co[$k], $cn[$k], $d)); $catMod++ }
    }
    foreach ($k in ($co.Keys | Sort-Object)) { if (-not $cn.ContainsKey($k)) { $lines.Add("  - catégorie « $k » (n'existe plus)"); $catDel++ } }
    $pAdd = 0; $pDel = 0; $pMov = 0; $detail = New-Object System.Collections.Generic.List[string]
    if ($HadIndex) {
        foreach ($id in $New.Keys) {
            if (-not $Old.ContainsKey($id)) { $pAdd++; if ($detail.Count -lt 300) { $detail.Add("  + fiche « $($New[$id]['t']) » dans « $((Get-BtCategOf $New[$id]).Cat) »") } }
            else {
                $a = (Get-BtCategOf $Old[$id]).Cat; $b = (Get-BtCategOf $New[$id]).Cat
                if ($a -ne $b) { $pMov++; if ($detail.Count -lt 300) { $detail.Add("  > fiche « $($New[$id]['t']) » déplacée : « $a » -> « $b »") } }
            }
        }
        foreach ($id in $Old.Keys) { if (-not $New.ContainsKey($id)) { $pDel++; if ($detail.Count -lt 300) { $detail.Add("  - fiche « $($Old[$id]['t']) » retirée de « $((Get-BtCategOf $Old[$id]).Cat) »") } } }
    }
    $summary = if ($HadIndex) { "catégories +$catAdd / -$catDel / ~$catMod ; fiches +$pAdd / -$pDel / déplacées $pMov" } else { "index créé : $($cn.Count) catégorie(s), $($New.Count) fiche(s)" }
    $out = New-Object System.Text.StringBuilder
    [void]$out.AppendLine("[$stamp] $(if ($Mode -eq 'full') { 'Analyse complète' } else { 'Mise à jour incrémentale' }) — $summary")
    if (-not $HadIndex) { foreach ($k in ($cn.Keys | Sort-Object)) { [void]$out.AppendLine("  = catégorie « $k » ($($cn[$k]) fiche(s))") } }
    foreach ($l in $lines) { [void]$out.AppendLine($l) }
    foreach ($l in $detail) { [void]$out.AppendLine($l) }
    if (($pAdd + $pDel + $pMov) -gt $detail.Count) { [void]$out.AppendLine("  … ($($pAdd + $pDel + $pMov - $detail.Count) autre(s) changement(s) de fiche non détaillé(s))") }
    $jf = Join-Path $Ctx.DataDir 'categories-journal.log'
    # Taille bornée : au-delà de 2 Mo, l'ancien journal devient .old (un seul conservé).
    try { if ((Test-Path -LiteralPath $jf) -and (Get-Item -LiteralPath $jf).Length -gt 2MB) { Move-Item -LiteralPath $jf -Destination ($jf + '.old') -Force } } catch { }
    try { [IO.File]::AppendAllText($jf, $out.ToString(), (New-Object System.Text.UTF8Encoding $true)) } catch { }
    return $summary
}

# --- Arborescence (pour l'onglet « Catégories ») -------------------------------------
# Nœud : @{ Name; Path; Kids = @{ nom = nœud }; Pages = List; Self = fiche du même nom ; N }
function Get-BtCategTree {
    param($Ctx)
    if ($Ctx.Categ.Tree) { return $Ctx.Categ.Tree }
    $idx = Read-BtCategIndex $Ctx
    if (-not $idx) { return $null }
    $root = @{ Name = ''; Path = ''; Kids = @{}; Pages = (New-Object System.Collections.Generic.List[object]); Self = $null; N = 0 }
    foreach ($id in $idx.Items.Keys) {
        $it = $idx.Items[$id]
        $a = @($it['a'])
        if (-not $a.Count) { continue }                       # accueil de l'espace
        $node = $root; $path = ''
        for ($i = 1; $i -lt $a.Count; $i++) {
            $name = [string]$a[$i]; $path += '/' + $name
            if (-not $node.Kids.ContainsKey($name)) { $node.Kids[$name] = @{ Name = $name; Path = $path; Kids = @{}; Pages = (New-Object System.Collections.Generic.List[object]); Self = $null; N = 0 } }
            $node = $node.Kids[$name]
        }
        $node.Pages.Add(@{ id = $id; it = $it })
    }
    # Fiche portant le nom d'un sous-nœud = page de rubrique : rattachée au nœud (bouton ↗).
    $finish = $null
    $finish = {
        param($n)
        $keep = New-Object System.Collections.Generic.List[object]
        foreach ($p in $n.Pages) {
            $t = [string]$p.it['t']
            if ($n.Kids.ContainsKey($t) -and -not $n.Kids[$t].Self) { $n.Kids[$t].Self = $p } else { $keep.Add($p) }
        }
        $n.Pages = $keep
        $sum = $keep.Count
        foreach ($k in $n.Kids.Values) { $sum += (& $finish $k) + $(if ($k.Self) { 1 } else { 0 }) }
        $n.N = $sum
        return $sum
    }
    [void](& $finish $root)
    $Ctx.Categ.Tree = $root
    return $root
}

# Rapport texte : uniquement des comptages + quelques titres d'exemple.
function Format-BtCategReport {
    param($Ctx, $R, $items)
    $sb = New-Object System.Text.StringBuilder
    $w = { param($s) [void]$sb.AppendLine($s) }
    $top = {
        param($pairs, [int]$n, [string]$indent = '  ')
        foreach ($g in @($pairs | Sort-Object Count -Descending | Select-Object -First $n)) {
            $ex = @($g.Group | Select-Object -First 3 | ForEach-Object { $_.t }) -join ' | '
            & $w ("{0}{1,5}  {2}    ex. {3}" -f $indent, $g.Count, $(if ($g.Name) { $g.Name } else { '(aucun)' }), $ex)
        }
    }
    & $w '=== Biblio-Tech : analyse des catégories (métadonnées uniquement) ==='
    & $w ("Date : {0}  ·  version {1}  ·  {2} fiche(s) dans l'index{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $Ctx.Config.Version, @($items).Count, $(if ($R.truncated) { ' (limite atteinte)' } else { '' }))
    & $w "Journal des changements : categories-journal.log (même dossier)."
    & $w ''
    & $w '--- Espaces ---'
    $names = @{}; foreach ($s in @($R.spaces)) { if ($s.k) { $names[[string]$s.k] = $s.n } }
    foreach ($g in @($items | Group-Object s | Sort-Object Count -Descending)) { & $w ("  {0,5}  {1}  {2}" -f $g.Count, $g.Name, $names[$g.Name]) }
    & $w ''
    & $w '--- Types ---'
    foreach ($g in @($items | Group-Object ty | Sort-Object Count -Descending)) { & $w ("  {0,5}  {1}" -f $g.Count, $g.Name) }
    & $w ''
    foreach ($lvl in 0..2) {
        & $w ("--- Arborescence : pages parentes de niveau {0} (0 = accueil de l'espace) ---" -f $lvl)
        $sel = @($items | Where-Object { @($_.a).Count -gt $lvl } | ForEach-Object { [pscustomobject]@{ k = [string]$_.a[$lvl]; t = $_.t } })
        & $top @($sel | Group-Object k) 40
        & $w ''
    }
    & $w '--- Chemins complets les plus fréquents (niveaux 1 > 2 > 3) ---'
    $paths = @($items | Where-Object { @($_.a).Count -gt 1 } | ForEach-Object { [pscustomobject]@{ k = (@($_.a | Select-Object -Skip 1 -First 3) -join ' > '); t = $_.t } })
    & $top @($paths | Group-Object k) 50
    & $w ''
    & $w '--- Étiquettes (labels) ---'
    $lab = @($items | ForEach-Object { $it = $_; @($it.l) | ForEach-Object { [pscustomobject]@{ k = [string]$_; t = $it.t } } })
    & $top @($lab | Group-Object k) 80
    & $w ("  Fiches sans étiquette : {0}" -f @($items | Where-Object { -not @($_.l).Count }).Count)
    & $w ''
    & $w '--- Combinaisons d''étiquettes les plus fréquentes ---'
    $combo = @($items | Where-Object { @($_.l).Count } | ForEach-Object { [pscustomobject]@{ k = (@($_.l | Sort-Object) -join ' + '); t = $_.t } })
    & $top @($combo | Group-Object k) 30
    & $w ''
    & $w '--- Préfixe de titre : premier symbole / émoji ---'
    $sym = @($items | ForEach-Object {
        $t = ([string]$_.t).Trim()
        $k = if ($t -and -not [char]::IsLetterOrDigit($t[0])) { ($t -split '\s', 2)[0] } else { '(lettre / chiffre)' }
        [pscustomobject]@{ k = $k; t = $_.t } })
    & $top @($sym | Group-Object k) 25
    & $w ''
    & $w '--- Préfixe de titre : texte avant « - », « : » ou « | » ---'
    $pre = @($items | ForEach-Object {
        $t = (([string]$_.t) -replace '^[^\p{L}\p{N}]+', '').Trim()
        $m = [regex]::Match($t, '^(.{2,40}?)\s+[-–:|]\s+')
        [pscustomobject]@{ k = $(if ($m.Success) { $m.Groups[1].Value } else { '' }); t = $_.t } } | Where-Object { $_.k })
    & $top @($pre | Group-Object k) 60
    & $w ''
    & $w '--- Premiers mots des titres (2 mots) ---'
    $fw = @($items | ForEach-Object {
        $t = (([string]$_.t) -replace '^[^\p{L}\p{N}]+', '').Trim()
        [pscustomobject]@{ k = ((@($t -split '\s+' | Select-Object -First 2)) -join ' ').ToLowerInvariant(); t = $_.t } })
    & $top @($fw | Group-Object k) 60
    return $sb.ToString()
}
