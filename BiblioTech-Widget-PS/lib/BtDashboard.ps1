# ============================================================================
#  Tableau de bord (analyse d'activité) : fenêtre WebView2 (profil partagé = session
#  SSO) qui charge une URL Confluence légère puis y INJECTE une page de graphiques :
#  les appels REST partent donc de l'origine Confluence (same-origin + cookie), comme
#  la recherche. Graphiques en SVG intégré (aucune bibliothèque externe).
#    - commentaires par jour sur une plage (commentaires initiaux / réponses) ;
#    - pages les plus commentées, contributeurs les plus actifs ;
#    - « consignes phares » (les plus consultées) : statistiques de consultation via
#      Confluence Analytics si l'API répond, sinon repli (à calibrer sur le terrain :
#      les essais sont journalisés en [DASH] dans app_debug.log).
#  Le JS remonte ses diagnostics à l'appli par chrome.webview.postMessage.
# ============================================================================

$script:BtDashXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Biblio-Tech · Tableau de bord" Width="1180" Height="820" MinWidth="760" MinHeight="520"
        WindowStartupLocation="CenterScreen" Background="#0F172A">
  <Grid x:Name="Host" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"/>
</Window>
'@

$script:BtDashJs = @'
(function(P){
  if (window.__btDash) return 'déjà chargé';
  window.__btDash = true;
  var base = P.base;
  function log(m){ try { window.chrome.webview.postMessage(String(m)); } catch(e){} }
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function esc(s){ return txt(s).replace(/[&<>"]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); }
  function ymd(d){ return d.getFullYear() + '-' + ('0'+(d.getMonth()+1)).slice(-2) + '-' + ('0'+d.getDate()).slice(-2); }
  function addDays(d, n){ var x = new Date(d.getTime()); x.setDate(x.getDate()+n); return x; }
  function get(u){
    return fetch(base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) throw new Error('session expirée (401)');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      var ct = txt(r.headers.get('content-type'));
      if (ct.indexOf('json') < 0) throw new Error('réponse non JSON');
      return r.json();
    });
  }

  document.title = 'Biblio-Tech · Tableau de bord';
  document.head.innerHTML = '<meta charset="utf-8"><title>Biblio-Tech · Tableau de bord</title><style>' + `
    :root{--bg:#0F172A;--card:#111C33;--line:#22314F;--txt:#E2E8F0;--mut:#94A3B8;--acc:#0088CE;--acc2:#F59E0B;--ok:#22C55E}
    *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--txt);font:13px "Segoe UI",sans-serif}
    header{position:sticky;top:0;z-index:2;background:#0B1220;border-bottom:2px solid var(--acc);padding:14px 22px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
    h1{font-size:17px;margin:0 18px 0 0;font-weight:600} label{color:var(--mut)}
    input[type=date]{background:#0F172A;color:var(--txt);border:1px solid var(--line);border-radius:6px;padding:5px 8px;color-scheme:dark}
    button{background:#16223D;color:var(--txt);border:1px solid var(--line);border-radius:14px;padding:5px 12px;cursor:pointer}
    button:hover{border-color:var(--acc)} button.pri{background:var(--acc);border-color:var(--acc)}
    #st{color:var(--mut);margin-left:auto}
    main{padding:18px 22px;display:grid;gap:16px}
    .kpis{display:grid;grid-template-columns:repeat(4,minmax(150px,1fr));gap:12px}
    .kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
    .kpi b{display:block;font-size:26px;font-weight:600;margin-top:4px} .kpi span{color:var(--mut)}
    .card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
    .card h2{font-size:14px;margin:0 0 10px;font-weight:600} .card p.note{color:var(--mut);margin:4px 0 10px}
    .two{display:grid;grid-template-columns:1fr 1fr;gap:16px}
    .row{display:grid;grid-template-columns:minmax(0,1fr) 140px 42px;gap:10px;align-items:center;padding:4px 0}
    .row a{color:var(--txt);text-decoration:none;white-space:nowrap;overflow:hidden;text-overflow:ellipsis} .row a:hover{color:var(--acc)}
    .bar{height:8px;border-radius:4px;background:var(--acc)} .num{text-align:right;color:var(--mut)}
    .leg{display:flex;gap:16px;color:var(--mut);margin-bottom:6px} .leg i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;vertical-align:-1px}
    svg text{fill:var(--mut);font-size:11px}
    @media (max-width:900px){.two{grid-template-columns:1fr}.kpis{grid-template-columns:repeat(2,1fr)}}
  ` + '</style>';
  document.body.innerHTML = `
    <header><h1>📊 Tableau de bord Biblio-Tech</h1>
      <label>Du <input type="date" id="from"></label><label>au <input type="date" id="to"></label>
      <button data-d="1">Aujourd'hui</button><button data-d="7">7 j</button><button data-d="30">30 j</button><button data-d="90">90 j</button>
      <button class="pri" id="go">Actualiser</button><button id="xl" title="Classeur Excel avec graphiques et liens, enregistré dans Téléchargements">⬇ Exporter Excel</button><span id="st"></span></header>
    <main>
      <div class="kpis">
        <div class="kpi"><span>Commentaires postés</span><b id="k1">–</b></div>
        <div class="kpi"><span>dont réponses</span><b id="k2">–</b></div>
        <div class="kpi"><span>Pages commentées</span><b id="k3">–</b></div>
        <div class="kpi"><span>Contributeurs</span><b id="k4">–</b></div>
      </div>
      <div class="card"><h2>Commentaires par jour</h2>
        <div class="leg"><span><i style="background:#0088CE"></i>Commentaires</span><span><i style="background:#F59E0B"></i>Réponses</span></div>
        <div id="chart"></div></div>
      <div class="two">
        <div class="card"><h2>⭐ Consignes phares — les plus consultées</h2><p class="note" id="vnote"></p><div id="views"></div></div>
        <div class="card"><h2>💬 Pages les plus commentées</h2><div id="topc"></div></div>
      </div>
      <div class="card"><h2>👤 Contributeurs les plus actifs</h2><div id="topu"></div></div>
    </main>`;

  var $ = function(id){ return document.getElementById(id); };
  var to0 = new Date(), from0 = addDays(to0, -29);
  $('from').value = ymd(from0); $('to').value = ymd(to0);
  Array.prototype.forEach.call(document.querySelectorAll('button[data-d]'), function(b){
    b.onclick = function(){ var n = +b.getAttribute('data-d'); var t = new Date(); $('to').value = ymd(t); $('from').value = ymd(addDays(t, -(n-1))); run(); };
  });
  $('go').onclick = run;
  // Export : les données affichées partent vers l'appli, qui fabrique le classeur Excel.
  var last = null;
  $('xl').onclick = function(){
    if (!last) { $('st').textContent = 'Rien à exporter : attendez la fin du chargement.'; return; }
    $('st').textContent = 'Export Excel en cours…';
    log('EXPORT:' + JSON.stringify(last));
  };

  function bars(list, max, link){
    if (!list.length) return '<p class="note">Aucune donnée sur la période.</p>';
    return list.map(function(x){
      var w = Math.max(3, Math.round(100 * x.n / max));
      var name = link && x.url ? '<a href="' + esc(x.url) + '" target="_blank" title="' + esc(x.k) + '">' + esc(x.k) + '</a>' : '<span title="' + esc(x.k) + '">' + esc(x.k) + '</span>';
      return '<div class="row">' + name + '<div><div class="bar" style="width:' + w + '%"></div></div><div class="num">' + x.n + '</div></div>';
    }).join('');
  }
  function topOf(map, n){ return Object.keys(map).map(function(k){ return map[k]; }).sort(function(a,b){ return b.n - a.n; }).slice(0, n); }

  function chart(days){
    var W = 1100, H = 240, L = 34, B = 26, T = 10, n = days.length;
    var max = Math.max(1, Math.max.apply(null, days.map(function(d){ return d.c + d.r; })));
    // Graduation « ronde » : 4 intervalles de 1, 2, 2.5 ou 5 × 10^n (jamais de décimales).
    var raw = max / 4, mag = Math.pow(10, Math.floor(Math.log10(raw)));
    var unit = [1, 2, 2.5, 5, 10].map(function(m){ return m * mag; }).filter(function(u){ return u >= raw && u >= 1 && (u % 1 === 0); })[0] || Math.ceil(raw);
    var top = unit * 4;
    var bw = (W - L - 6) / n, s = '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%" preserveAspectRatio="none" style="height:' + H + 'px">';
    for (var g = 0; g <= 4; g++) { var v = Math.round(top * g / 4), y = H - B - (H - B - T) * g / 4;
      s += '<line x1="' + L + '" x2="' + W + '" y1="' + y + '" y2="' + y + '" stroke="#22314F"/><text x="' + (L-6) + '" y="' + (y+4) + '" text-anchor="end">' + v + '</text>'; }
    var every = Math.max(1, Math.ceil(n / 15));
    days.forEach(function(d, i){
      var x = L + 3 + i * bw, hc = (H - B - T) * d.c / top, hr = (H - B - T) * d.r / top, w = Math.max(1, bw - 2);
      var tip = '<title>' + d.label + ' : ' + d.c + ' commentaire(s), ' + d.r + ' réponse(s)</title>';
      s += '<g>' + tip + '<rect x="' + x + '" y="' + (H - B - hc) + '" width="' + w + '" height="' + hc + '" fill="#0088CE" rx="2"/>'
         + '<rect x="' + x + '" y="' + (H - B - hc - hr) + '" width="' + w + '" height="' + hr + '" fill="#F59E0B" rx="2"/>'
         + '<rect x="' + x + '" y="' + T + '" width="' + w + '" height="' + (H - B - T) + '" fill="transparent"/></g>';
      if (i % every === 0) s += '<text x="' + (x + w/2) + '" y="' + (H - 8) + '" text-anchor="middle">' + d.label.slice(0,5) + '</text>';
    });
    return s + '</svg>';
  }

  // --- Consultations : essais d'API Confluence Analytics (journalisés pour calibrage).
  var viewTried = false;
  function views(from, to){
    var sp = P.space ? '&spaceKey=' + encodeURIComponent(P.space) : '';
    var cands = [
      '/rest/confanalytics/1.0/instance/topContent?limit=15&fromDate=' + from + '&toDate=' + to + sp,
      '/rest/confanalytics/1.0/content/topViewed?limit=15&fromDate=' + from + '&toDate=' + to + sp,
      '/rest/confanalytics/1.0/space/topContent?limit=15&fromDate=' + from + '&toDate=' + to + sp,
      '/rest/popular/1/stream/content?days=30&pageSize=15'
    ];
    function pick(j){
      var arr = Array.isArray(j) ? j : (j && (j.results || j.content || j.items || j.data || j.rows)) || [];
      return arr.map(function(o){
        var c = o.content || o.entity || o;
        var k = txt(c.title || o.title || o.name);
        var n = +(o.views || o.viewCount || o.count || o.total || o.value || (o.statistics && o.statistics.views) || 0);
        var u = txt((c._links && c._links.webui) || o.url || o.link);
        return {k:k, n:n, url: u ? (/^https?:/.test(u) ? u : base + u) : ''};
      }).filter(function(x){ return x.k && x.n > 0; });
    }
    var i = 0;
    function next(){
      if (i >= cands.length) return Promise.resolve(null);
      var u = cands[i++];
      return get(u).then(function(j){
        var list = pick(j);
        if (!viewTried) log('[DASH] consultations ' + u.split('?')[0] + ' -> OK, ' + list.length + ' élément(s) ; clés=' + Object.keys(j || {}).slice(0, 12).join(','));
        return list.length ? list : next();
      }, function(e){ if (!viewTried) log('[DASH] consultations ' + u.split('?')[0] + ' -> ' + e.message); return next(); });
    }
    return next().then(function(r){ viewTried = true; return r; });
  }

  var runId = 0;
  function run(){
    var id = ++runId, from = $('from').value, to = $('to').value;
    if (!from || !to || from > to) { $('st').textContent = 'Plage de dates invalide.'; return; }
    var toNext = ymd(addDays(new Date(to + 'T00:00:00'), 1));
    var cql = 'type = comment AND created >= "' + from + '" AND created < "' + toNext + '"' + (P.space ? ' AND space = "' + P.space + '"' : '');
    var all = [], t0 = Date.now();
    $('st').textContent = 'Chargement des commentaires…';
    function page(start){
      return get('/rest/api/content/search?cql=' + encodeURIComponent(cql) + '&start=' + start + '&limit=50&expand=' + encodeURIComponent('ancestors,container,history'))
        .then(function(j){
          if (id !== runId) return;
          var res = j.results || []; all = all.concat(res);
          $('st').textContent = 'Chargement des commentaires… ' + all.length + (typeof j.totalSize === 'number' ? ' / ' + j.totalSize : '');
          if (res.length && j._links && j._links.next && all.length < P.max) return page(start + res.length);
        });
    }
    page(0).then(function(){
      if (id !== runId) return;
      var dayMap = {}, pages = {}, users = {}, nReply = 0;
      for (var d = new Date(from + 'T00:00:00'); ymd(d) <= to; d = addDays(d, 1)) dayMap[ymd(d)] = {c:0, r:0, label: ymd(d).slice(8,10) + '/' + ymd(d).slice(5,7) + '/' + ymd(d).slice(0,4)};
      all.forEach(function(c){
        var h = c.history || {}, when = txt(h.createdDate).slice(0, 10);
        var isReply = (c.ancestors || []).some(function(a){ return a.type === 'comment'; });
        if (isReply) nReply++;
        if (dayMap[when]) { if (isReply) dayMap[when].r++; else dayMap[when].c++; }
        var ct = c.container || {}, pk = txt(ct.id || ct.title);
        if (pk) { pages[pk] = pages[pk] || {k: txt(ct.title), n:0, url: ct._links && ct._links.webui ? base + ct._links.webui : ''}; pages[pk].n++; }
        var by = txt(h.createdBy && (h.createdBy.displayName || h.createdBy.username));
        if (by) { users[by] = users[by] || {k: by, n:0}; users[by].n++; }
      });
      var days = Object.keys(dayMap).sort().map(function(k){ return dayMap[k]; });
      $('k1').textContent = all.length; $('k2').textContent = nReply;
      $('k3').textContent = Object.keys(pages).length; $('k4').textContent = Object.keys(users).length;
      $('chart').innerHTML = chart(days);
      var tp = topOf(pages, 12); $('topc').innerHTML = bars(tp, tp.length ? tp[0].n : 1, true);
      var tu = topOf(users, 12); $('topu').innerHTML = bars(tu, tu.length ? tu[0].n : 1, false);
      $('st').textContent = all.length + ' commentaire(s) du ' + from + ' au ' + to + (all.length >= P.max ? ' (limite atteinte)' : '') + ' · ' + Math.round((Date.now()-t0)/100)/10 + ' s';
      log('[DASH] ' + from + '..' + to + ' : ' + all.length + ' commentaire(s), ' + nReply + ' réponse(s), ' + Object.keys(pages).length + ' page(s)');
      last = { from: from, to: to, base: base, total: all.length, replies: nReply, pages: Object.keys(pages).length, users: Object.keys(users).length,
               truncated: all.length >= P.max, days: days.map(function(d){ return {d: d.label, c: d.c, r: d.r}; }),
               topPages: topOf(pages, 100), topUsers: topOf(users, 100), views: null, viewsSource: '' };
      return views(from, to).then(function(v){
        if (id !== runId) return;
        if (v && v.length) {
          $('vnote').textContent = 'Source : statistiques de consultation Confluence.'; $('views').innerHTML = bars(v.slice(0, 12), v[0].n, true);
          last.views = v.slice(0, 50); last.viewsSource = 'Consultations (statistiques Confluence)';
        } else {
          $('vnote').textContent = 'Statistiques de consultation indisponibles via l\'API sur cette instance (calibrage en cours) : en attendant, pages les plus commentées sur la période.';
          $('views').innerHTML = bars(tp.slice(0, 8), tp.length ? tp[0].n : 1, true);
          last.views = tp.slice(0, 8); last.viewsSource = 'Commentaires (consultations indisponibles via l\'API)';
        }
      });
    }).catch(function(e){
      if (id !== runId) return;
      $('st').textContent = 'Erreur : ' + e.message;
      log('[DASH] Échec du chargement : ' + e.message);
    });
  }
  run();
  return 'ok';
})(__P__)
'@

# --- Export Excel (COM : Excel déjà installé sur le poste, aucun .exe livré) ---------
# Feuilles : Synthèse (indicateurs + graphiques natifs), Par jour, Pages commentées,
# Consignes phares, Contributeurs. Titres de pages = liens cliquables vers Confluence.
function New-BtDashboardWorkbook {
    param($Data, [string]$Path, [string]$Version = '')
    $xl = $null; $wb = $null

    try {
        $xl = New-Object -ComObject Excel.Application
        $xl.Visible = $false; $xl.DisplayAlerts = $false; $xl.ScreenUpdating = $false
        $wb = $xl.Workbooks.Add()
        while ($wb.Worksheets.Count -lt 5) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
        $names = @('Synthèse', 'Par jour', 'Pages commentées', 'Consignes phares', 'Contributeurs')
        for ($i = 1; $i -le 5; $i++) { $wb.Worksheets.Item($i).Name = $names[$i - 1] }
        # Écriture par blocs (object[,] -> Range.Value2) : l'affectation cellule par cellule
        # de nombres via COM échoue sous PowerShell (« cast Double -> String »).
        $put = {
            param($ws, [int]$r, [int]$c, [System.Collections.Generic.List[object[]]]$rows)
            if (-not $rows.Count) { return }
            $n = $rows.Count; $m = $rows[0].Length
            $a = New-Object 'object[,]' $n, $m
            for ($i = 0; $i -lt $n; $i++) { for ($j = 0; $j -lt $m; $j++) { $a[$i, $j] = $rows[$i][$j] } }
            $ws.Range($ws.Cells.Item($r, $c), $ws.Cells.Item($r + $n - 1, $c + $m - 1)).Value2 = $a
        }
        $one = { param($ws, [int]$r, [int]$c, $v) $l = New-Object 'System.Collections.Generic.List[object[]]'; $l.Add([object[]]@($v)); & $put $ws $r $c $l }
        $head = {
            param($ws, [string[]]$cols)
            $l = New-Object 'System.Collections.Generic.List[object[]]'; $l.Add([object[]]$cols); & $put $ws 1 1 $l
            $h = $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item(1, $cols.Count))
            $h.Font.Bold = $true; $h.Font.Color = 0xFFFFFF; $h.Interior.Color = 0xCE8800   # BGR : bleu #0088CE
        }
        # Liste {k, n, url} -> feuille (titre en lien + nombre). Renvoie la dernière ligne.
        $list = {
            param($ws, $rows, [string]$label, [string]$numLabel)
            & $head $ws @($label, $numLabel)
            $ws.Columns.Item(1).NumberFormat = '@'          # texte (un titre « =… » n'est pas une formule)
            $l = New-Object 'System.Collections.Generic.List[object[]]'
            foreach ($x in @($rows)) { $l.Add([object[]]@([string]$x.k, [double]$x.n)) }
            & $put $ws 2 1 $l
            $r = 2
            foreach ($x in @($rows)) {
                if ($x.url) { [void]$ws.Hyperlinks.Add($ws.Cells.Item($r, 1), [string]$x.url, '', [string]$x.url, [string]$x.k) }
                $r++
            }
            $ws.Columns.Item(1).ColumnWidth = 80; $ws.Columns.Item(2).ColumnWidth = 16
            return ($r - 1)
        }

        # Par jour.
        $wsD = $wb.Worksheets.Item(2)
        & $head $wsD @('Date', 'Commentaires', 'Réponses', 'Total')
        $l = New-Object 'System.Collections.Generic.List[object[]]'
        $r = 2
        foreach ($d in @($Data.days)) {
            $dt = [datetime]::ParseExact([string]$d.d, 'dd/MM/yyyy', [Globalization.CultureInfo]::InvariantCulture)
            $l.Add([object[]]@($dt.ToOADate(), [double]$d.c, [double]$d.r, "=B$r+C$r"))
            $r++
        }
        & $put $wsD 2 1 $l
        $lastDay = $r - 1
        # Via COM depuis PowerShell, Excel lit NumberFormat dans la langue de l'utilisateur
        # (« jj/mm/aaaa » en français, « dd/mm/yyyy » en anglais) : on essaie les deux.
        $rngD = $wsD.Range("A2:A$([Math]::Max(2, $lastDay))")
        foreach ($fmt in @('jj/mm/aaaa', 'dd/mm/yyyy', 'tt.mm.jjjj')) { try { $rngD.NumberFormat = $fmt; break } catch { } }
        $wsD.Columns.Item(1).ColumnWidth = 14
        foreach ($c in 2..4) { $wsD.Columns.Item($c).ColumnWidth = 15 }

        $nP = & $list $wb.Worksheets.Item(3) $Data.topPages 'Page' 'Commentaires'
        $isViews = ([string]$Data.viewsSource) -like 'Consultations*'
        $nV = & $list $wb.Worksheets.Item(4) $Data.views 'Consigne / page' $(if ($isViews) { 'Consultations' } else { 'Commentaires' })
        & $one $wb.Worksheets.Item(4) ($nV + 2) 1 "Source : $($Data.viewsSource)"
        $nU = & $list $wb.Worksheets.Item(5) $Data.topUsers 'Contributeur' 'Commentaires'

        # Synthèse : indicateurs + graphiques natifs.
        $ws = $wb.Worksheets.Item(1)
        & $one $ws 1 1 'Tableau de bord Biblio-Tech'
        $ws.Cells.Item(1, 1).Font.Size = 18; $ws.Cells.Item(1, 1).Font.Bold = $true
        & $one $ws 2 1 ("Période du $($Data.from) au $($Data.to)  ·  extrait le $(Get-Date -Format 'dd/MM/yyyy HH:mm')" + $(if ($Version) { "  ·  Biblio-Tech $Version" } else { '' }))
        $ws.Cells.Item(2, 1).Font.Color = 0x808080
        $k = New-Object 'System.Collections.Generic.List[object[]]'
        $k.Add([object[]]@('Commentaires postés', '', 'dont réponses', '', 'Pages commentées', '', 'Contributeurs'))
        $k.Add([object[]]@([double]$Data.total, '', [double]$Data.replies, '', [double]$Data.pages, '', [double]$Data.users))
        & $put $ws 4 1 $k
        $ws.Range('A4:G4').Font.Color = 0x808080
        $ws.Range('A5:G5').Font.Size = 20; $ws.Range('A5:G5').Font.Bold = $true; $ws.Range('A5:G5').HorizontalAlignment = -4131   # gauche
        if ($Data.truncated) { & $one $ws 6 1 '(limite de chargement atteinte : chiffres partiels)' }
        foreach ($c in 1..8) { $ws.Columns.Item($c).ColumnWidth = 17 }
        & $one $ws 7 1 'Ouvrir Biblio-Tech (Confluence)'
        [void]$ws.Hyperlinks.Add($ws.Cells.Item(7, 1), [string]$Data.base, '', '', 'Ouvrir Biblio-Tech (Confluence)')
        $top = $ws.Rows.Item(9).Top
        if ($lastDay -ge 2) {
            $co = $ws.ChartObjects().Add(5, $top, 780, 280)
            $ch = $co.Chart
            $ch.ChartType = 52                                  # xlColumnStacked
            $ch.SetSourceData($wsD.Range("A1:C$lastDay"))
            $ch.HasTitle = $true; $ch.ChartTitle.Text = 'Commentaires par jour'
            try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0xCE8800; $ch.SeriesCollection(2).Format.Fill.ForeColor.RGB = 0x0B9EF5 } catch { }
            $top += 295
        }
        $chartList = {
            param($srcWs, [int]$n, [string]$title, [double]$y, [double]$x, [int]$color)
            if ($n -lt 2) { return }
            $last = [Math]::Min($n, 11)                         # 10 premiers
            $co = $ws.ChartObjects().Add($x, $y, 385, 300)
            $ch = $co.Chart
            $ch.ChartType = 57                                  # xlBarClustered
            $ch.SetSourceData($srcWs.Range("A1:B$last"))
            $ch.HasTitle = $true; $ch.ChartTitle.Text = $title; $ch.HasLegend = $false
            try { $ch.Axes(1).ReversePlotOrder = $true } catch { }   # le n°1 en haut
            try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = $color } catch { }
        }
        & $chartList $wb.Worksheets.Item(4) $nV 'Consignes phares' $top 5 0x0B9EF5
        & $chartList $wb.Worksheets.Item(3) $nP 'Pages les plus commentées' $top 400 0xCE8800
        $ws.Activate()
        $wb.SaveAs($Path, 51)                                   # xlOpenXMLWorkbook (.xlsx)
    } finally {
        if ($wb) { try { $wb.Close($false) } catch { }; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
        if ($xl) { try { $xl.Quit() } catch { }; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Export-BtDashboardExcel {
    param($Ctx, [string]$Json)
    $say = { param($t) try { [void]$script:Ctx.Dash.WebView.CoreWebView2.ExecuteScriptAsync("document.getElementById('st').textContent = " + (ConvertTo-Json ([string]$t))) } catch { } }
    try {
        $data = $Json | ConvertFrom-Json
        $dir = $null
        try { $dir = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch { }
        if (-not $dir -or -not (Test-Path $dir)) { $dir = [Environment]::GetFolderPath('MyDocuments') }
        $path = Join-Path $dir ("Biblio-Tech tableau de bord {0} au {1} ({2}).xlsx" -f $data.from, $data.to, (Get-Date -Format 'yyyy-MM-dd HH\hmm'))
        Write-BtLog "[DASH] Export Excel -> $path"
        New-BtDashboardWorkbook $data $path $Ctx.Config.Version
        & $say "Export Excel enregistré : $path"
        try { Start-Process -FilePath $path } catch { }
    } catch {
        Write-BtLog "[DASH] Export Excel KO : $($_.Exception.Message)"
        & $say "Export Excel impossible (Excel installé ?) : $($_.Exception.Message)"
    }
}

function Show-BtDashboard {
    param($Ctx)
    if ($Ctx.Demo) { Show-BtFlash $Ctx 'Tableau de bord indisponible en mode démonstration.'; return }
    if (-not $script:BtWebView2Ok) { Show-BtFlash $Ctx 'WebView2 absent : tableau de bord indisponible.'; return }
    if (-not $Ctx.Ready) { Show-BtFlash $Ctx 'Connexion à Confluence requise pour le tableau de bord.'; return }
    $d = $Ctx.Dash
    if (-not $d.Window) {
        $win = [System.Windows.Markup.XamlReader]::Parse($script:BtDashXaml)
        $ico = New-BtImageSource (Get-BtAppIconPath 'png') 64
        if ($ico) { $win.Icon = $ico }
        Register-BtWindowIcon $win
        $wv = New-BtWebView $Ctx
        [void]$win.FindName('Host').Children.Add($wv)
        $d.Window = $win; $d.WebView = $wv
        $wv.add_CoreWebView2InitializationCompleted({ param($s, $e)
            if (-not $e.IsSuccess) { Write-BtLog "[DASH] Init WebView2 KO : $($e.InitializationException.Message)"; return }
            $cw = $s.CoreWebView2
            # Liens des listes -> navigateur par défaut.
            $cw.add_NewWindowRequested({ param($a, $b) $b.Handled = $true; Open-BtExternal ([string]$b.Uri) })
            # Diagnostics remontés par la page -> journal de l'appli.
            $cw.add_WebMessageReceived({ param($a, $b)
                $m = ''; try { $m = [string]$b.TryGetWebMessageAsString() } catch { }
                if ($m.StartsWith('EXPORT:')) { Export-BtDashboardExcel $script:Ctx $m.Substring(7) }
                elseif ($m) { Write-BtLog $m } })
        })
        $wv.add_NavigationCompleted({ param($s, $e)
            $c = $script:Ctx
            $u = $null; try { $u = $s.Source } catch { }
            if (-not $u -or $u.Scheme -eq 'about' -or $u.Scheme -eq 'data') { return }
            if ($u.Host -ne $c.ConfHost -or $u.AbsolutePath -match '(?i)/(login|dologin|authenticate)\.action') {
                Write-BtLog '[DASH] Session non valide : tableau de bord non chargé.'
                try { $s.NavigateToString('<body style="background:#0F172A;color:#E2E8F0;font:14px Segoe UI;padding:40px">Connexion à Confluence requise : connectez-vous depuis la fenêtre principale de Biblio-Tech puis rouvrez le tableau de bord.</body>') } catch { }
                return
            }
            $p = @{ base = $c.Config.BaseUrl.TrimEnd('/'); space = [string]$c.Config.SpaceKey; max = [int]$c.Config.DashMaxComments } | ConvertTo-Json -Compress
            try { [void]$s.CoreWebView2.ExecuteScriptAsync($script:BtDashJs.Replace('__P__', $p)) } catch { Write-BtLog "[DASH] Injection KO : $($_.Exception.Message)" }
        })
        $win.Add_Closing({ param($s, $e) if (-not $script:Ctx.Quitting) { $e.Cancel = $true; $s.Hide() } })
        # Page Confluence légère (JSON) servant d'origine à la page injectée.
        $wv.Source = [uri]($Ctx.Config.BaseUrl.TrimEnd('/') + '/rest/api/user/current')
        Write-BtLog '[DASH] Tableau de bord ouvert.'
    } elseif (-not $d.Window.IsVisible) {
        # Réouverture : on recharge pour repartir de données fraîches.
        try { $d.WebView.Reload() } catch { }
    }
    $d.Window.Show()
    if ($d.Window.WindowState -eq [System.Windows.WindowState]::Minimized) { $d.Window.WindowState = [System.Windows.WindowState]::Normal }
    $d.Window.Activate() | Out-Null
}
