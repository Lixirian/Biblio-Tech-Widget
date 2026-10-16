# ============================================================================
#  Analyse des catégories (DIAGNOSTIC, local uniquement).
#  Parcourt les MÉTADONNÉES des pages Confluence (titre, arborescence des pages
#  parentes, étiquettes, espace, type) — jamais le contenu — et écrit un journal
#  de synthèse dans %LOCALAPPDATA%\BiblioTech-Widget\analyse-categories.txt.
#  Rien n'est envoyé ailleurs : l'utilisateur transmet ce fichier s'il le souhaite,
#  pour ajuster le classement par catégories des résultats.
#  Lancée une fois par version après la connexion, et via le menu « … ».
# ============================================================================

$script:BtCategJs = @'
(function(P){
  window.__btInv = {state:'PENDING', id:P.id, done:0};
  var t0 = Date.now(), items = [], spaces = [], total = -1;
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function get(u){
    return fetch(P.base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) throw new Error('HTTP 401 (session expirée)');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }
  function page(start){
    var q = 'cql=' + encodeURIComponent(P.cql) + '&start=' + start + '&limit=' + P.limit + '&expand=' + encodeURIComponent('ancestors,metadata.labels,space');
    return get('/rest/api/content/search?' + q).then(function(j){
      if (typeof j.totalSize === 'number') total = j.totalSize;
      (j.results || []).forEach(function(c){
        var a = [], l = [];
        try { (c.ancestors || []).forEach(function(x){ a.push(txt(x.title)); }); } catch(e){}
        try { (c.metadata.labels.results || []).forEach(function(x){ l.push(txt(x.name)); }); } catch(e){}
        items.push({t:txt(c.title), ty:txt(c.type), s:txt(c.space && c.space.key), a:a, l:l});
      });
      window.__btInv = {state:'PENDING', id:P.id, done:items.length};
      var more = (j.results || []).length > 0 && !!(j._links && j._links.next);
      if (more && items.length < P.max) return page(start + (j.results || []).length);
    });
  }
  get('/rest/api/space?limit=200').then(function(j){
    (j.results || []).forEach(function(s){ spaces.push({k:txt(s.key), n:txt(s.name), ty:txt(s.type)}); });
  }).catch(function(){}).then(function(){ return page(0); }).then(function(){
    window.__btInv = {state:'OK', id:P.id, items:items, spaces:spaces, total:total, truncated:items.length >= P.max, ms:Date.now()-t0};
  }).catch(function(e){
    window.__btInv = {state:'ERROR', id:P.id, error:txt(e && e.message), items:items, spaces:spaces, total:total, ms:Date.now()-t0};
  });
  return 'started';
})(__P__)
'@

# Le sondage ne renvoie qu'un petit objet tant que l'analyse tourne (pas la liste entière).
$script:BtCategPollJs = "(window.__btInv && window.__btInv.state === 'PENDING') ? {state:'PENDING', id:window.__btInv.id} : window.__btInv"

function Start-BtCategScan {
    param($Ctx, [switch]$Manual)
    $c = $Ctx.Categ
    if ($c.Probe.Phase -ne '') { if ($Manual) { Show-BtFlash $Ctx 'Analyse des catégories déjà en cours…' }; return }
    if (-not ($Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2)) {
        if ($Manual) { Show-BtFlash $Ctx 'Connexion à Confluence requise pour analyser les catégories.' }
        return
    }
    $cql = 'type in (page, blogpost)'
    if ($Ctx.Config.SpaceKey) { $cql = ('space = "{0}" AND ' -f (ConvertTo-BtCqlString $Ctx.Config.SpaceKey)) + $cql }
    $c.Id = [guid]::NewGuid().ToString('N')
    $c.Manual = [bool]$Manual
    $c.StartedAt = Get-Date
    $p = @{ id = $c.Id; base = $Ctx.Config.BaseUrl.TrimEnd('/'); cql = $cql; limit = 50; max = [int]$Ctx.Config.CategScanMax } | ConvertTo-Json -Compress
    Write-BtLog "[CATEG] Analyse des catégories lancée (max $($Ctx.Config.CategScanMax) pages)."
    if ($Manual) { Show-BtFlash $Ctx 'Analyse des catégories en cours (1 à 2 min)…' }
    Start-BtProbe $Ctx $c.Probe ($script:BtCategJs.Replace('__P__', $p)) $script:BtCategPollJs 600 $c.Id
}

function Step-BtCategScan {
    param($Ctx)
    $c = $Ctx.Categ
    if ($c.Probe.Phase -eq '') {
        # Automatique : une fois par version, un peu après la connexion (laisse passer la 1re recherche).
        if ($Ctx.Ready -and -not $Ctx.Demo -and $Ctx.State.CategScanVersion -ne $Ctx.Config.Version -and
            $c.AutoAt -and (Get-Date) -ge $c.AutoAt) {
            $c.AutoAt = $null
            Start-BtCategScan $Ctx
        }
        return
    }
    $r = Step-BtProbe $Ctx $c.Probe
    if ($r) { Complete-BtCategScan $Ctx $r }
}

function Complete-BtCategScan {
    param($Ctx, $R)
    $c = $Ctx.Categ
    $items = @($R.items | Where-Object { $_ })
    if ($R.state -ne 'OK' -and -not $items.Count) {
        Write-BtLog "[CATEG] Échec de l'analyse ($($R.state) $($R.error))."
        if ($c.Manual) { Show-BtFlash $Ctx "Analyse des catégories impossible : $($R.error)" }
        return
    }
    $path = Join-Path $Ctx.DataDir 'analyse-categories.txt'
    try {
        $txt = Format-BtCategReport $Ctx $R $items
        [System.IO.File]::WriteAllText($path, $txt, (New-Object System.Text.UTF8Encoding $true))
        $Ctx.State.CategScanVersion = $Ctx.Config.Version
        Save-BtState $Ctx.State
        Write-BtLog ("[CATEG] Analyse terminée : {0} page(s) analysée(s) sur {1} en {2} s -> {3}" -f $items.Count, $R.total, [int]($R.ms / 1000), $path)
        if ($R.state -ne 'OK') { Write-BtLog "[CATEG] Analyse partielle : $($R.error)" }
        if ($c.Manual) { try { Start-Process notepad.exe -ArgumentList ('"' + $path + '"') } catch { } }
        else { Show-BtFlash $Ctx 'Analyse des catégories enregistrée (menu … > Ouvrir l''analyse des catégories).' }
    } catch { Write-BtLog "[CATEG] Écriture du rapport KO : $($_.Exception.Message)" }
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
    & $w ("Date : {0}  ·  version {1}  ·  {2} page(s) analysée(s) sur {3}{4}  ·  {5} s" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $Ctx.Config.Version, $items.Count, $R.total, $(if ($R.truncated) { ' (limite atteinte)' } else { '' }), [int]($R.ms / 1000))
    & $w ''
    & $w '--- Espaces (pages analysées) ---'
    $names = @{}; foreach ($s in @($R.spaces)) { if ($s.k) { $names[$s.k] = $s.n } }
    foreach ($g in @($items | Group-Object s | Sort-Object Count -Descending)) { & $w ("  {0,5}  {1}  {2}" -f $g.Count, $g.Name, $names[$g.Name]) }
    & $w ("  Espaces visibles au total : {0}" -f @($R.spaces).Count)
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
    & $w ("  Pages sans étiquette : {0}" -f @($items | Where-Object { -not @($_.l).Count }).Count)
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
