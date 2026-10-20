# ============================================================================
#  Tableau de bord (analyse d'activité) : fenêtre WebView2 (profil partagé = session
#  SSO) qui charge une URL Confluence légère puis y INJECTE une page de graphiques :
#  les appels REST partent donc de l'origine Confluence (same-origin + cookie), comme
#  la recherche. Graphiques en SVG intégré (aucune bibliothèque externe).
#    - commentaires / réponses par jour, comparaison avec la période précédente ;
#    - commentaires sans réponse + délai de première réponse ;
#    - jours × heures d'activité ;
#    - activité éditoriale (fiches créées / mises à jour), nouvelles consignes ;
#    - fiches à revoir (> 12 mois sans mise à jour), répartition par rubrique ;
#    - consignes phares (consultations Confluence Analytics si l'API répond, sinon
#      repli), « J'aime » ; pages les plus commentées, contributeurs.
#  Les essais d'API incertains sont journalisés en [DASH] (calibrage terrain).
#  Export Excel (COM) avec graphiques natifs et liens.
# ============================================================================

$script:BtDashXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Biblio-Tech · Tableau de bord" Width="1240" Height="860" MinWidth="760" MinHeight="520"
        WindowStartupLocation="CenterScreen" Background="#0F172A">
  <Grid x:Name="Host" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"/>
</Window>
'@

$script:BtDashJs = @'
(function(P){
  if (window.__btDash) return 'déjà chargé';
  window.__btDash = true;
  var base = P.base, SPACE = P.space ? ' AND space = "' + P.space + '"' : '';
  function log(m){ try { window.chrome.webview.postMessage(String(m)); } catch(e){} }
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function esc(s){ return txt(s).replace(/[&<>"]/g, function(c){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]; }); }
  function ymd(d){ return d.getFullYear() + '-' + ('0'+(d.getMonth()+1)).slice(-2) + '-' + ('0'+d.getDate()).slice(-2); }
  function fr(s){ return s ? s.slice(8,10) + '/' + s.slice(5,7) + '/' + s.slice(0,4) : ''; }
  function addDays(d, n){ var x = new Date(d.getTime()); x.setDate(x.getDate()+n); return x; }
  function D(s){ return new Date(s + 'T00:00:00'); }
  function get(u){
    return fetch(base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) throw new Error('session expirée (401)');
      if (!r.ok) throw new Error('HTTP ' + r.status);
      if (txt(r.headers.get('content-type')).indexOf('json') < 0) throw new Error('réponse non JSON');
      return r.json();
    });
  }
  // Tous les résultats d'une requête CQL (contenu), jusqu'à max.
  function searchAll(cql, expand, max, onProgress){
    var all = [];
    function page(start){
      return get('/rest/api/content/search?cql=' + encodeURIComponent(cql) + '&start=' + start + '&limit=50' + (expand ? '&expand=' + encodeURIComponent(expand) : ''))
        .then(function(j){
          var res = j.results || []; all = all.concat(res);
          if (onProgress) onProgress(all.length, j.totalSize);
          if (res.length && j._links && j._links.next && all.length < max) return page(start + res.length);
          return all;
        });
    }
    return page(0);
  }
  // Nombre de résultats (sans les charger).
  function count(cql){
    return get('/rest/api/search?cql=' + encodeURIComponent(cql) + '&limit=1')
      .then(function(j){ return (typeof j.totalSize === 'number') ? j.totalSize : null; }, function(){ return null; });
  }

  document.title = 'Biblio-Tech · Tableau de bord';
  document.head.innerHTML = '<meta charset="utf-8"><title>Biblio-Tech · Tableau de bord</title><style>' + `
    :root{--bg:#0F172A;--card:#111C33;--line:#22314F;--txt:#E2E8F0;--mut:#94A3B8;--acc:#0088CE;--acc2:#F59E0B;--ok:#22C55E;--ko:#EF4444;--hdr:#0B1220;--btn:#16223D;--row:#1A2742;--tag:#3B2A0B;color-scheme:dark}
    @media (prefers-color-scheme: light){:root{--bg:#F4F6FA;--card:#FFFFFF;--line:#D5DCE7;--txt:#1E293B;--mut:#5B6B82;--acc2:#B45309;--ok:#15803D;--ko:#DC2626;--hdr:#FFFFFF;--btn:#EEF2F7;--row:#E6EBF2;--tag:#FDF0D9;color-scheme:light}}
    *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--txt);font:13px "Segoe UI",sans-serif}
    header{position:sticky;top:0;z-index:2;background:var(--hdr);border-bottom:2px solid var(--acc);padding:12px 22px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
    h1{font-size:17px;margin:0 14px 0 0;font-weight:600} label{color:var(--mut)}
    input[type=date]{background:var(--bg);color:var(--txt);border:1px solid var(--line);border-radius:6px;padding:5px 8px}
    button{background:var(--btn);color:var(--txt);border:1px solid var(--line);border-radius:14px;padding:5px 12px;cursor:pointer}
    button:hover{border-color:var(--acc)} button.pri{background:var(--acc);border-color:var(--acc);color:#fff}
    #st{color:var(--mut);margin-left:auto}
    main{padding:16px 22px;display:grid;gap:14px}
    .kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(165px,1fr));gap:12px}
    .kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
    .kpi b{display:block;font-size:24px;font-weight:600;margin-top:4px} .kpi span{color:var(--mut)} .kpi small{display:block;margin-top:2px;color:var(--mut)}
    .up{color:var(--ok)!important} .down{color:var(--ko)!important} .warn b{color:var(--acc2)}
    .card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;min-width:0}
    .card h2{font-size:14px;margin:0 0 10px;font-weight:600} p.note{color:var(--mut);margin:4px 0 10px}
    .two{display:grid;grid-template-columns:1fr 1fr;gap:14px}
    .row{display:grid;grid-template-columns:minmax(0,1fr) 130px 46px;gap:10px;align-items:center;padding:4px 0}
    a{color:var(--txt);text-decoration:none} a:hover{color:var(--acc)}
    .row a,.row span.k{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .bar{height:8px;border-radius:4px;background:var(--acc)} .num{text-align:right;color:var(--mut)}
    table{width:100%;border-collapse:collapse} th{color:var(--mut);font-weight:400;text-align:left;padding:4px 6px;border-bottom:1px solid var(--line)}
    td{padding:5px 6px;border-bottom:1px solid var(--row);max-width:420px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .tag{display:inline-block;padding:0 6px;border-radius:8px;font-size:11px;background:var(--tag);color:var(--acc2)}
    .leg{display:flex;gap:16px;color:var(--mut);margin-bottom:6px;flex-wrap:wrap} .leg i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;vertical-align:-1px}
    svg text{fill:var(--mut);font-size:11px}
    .scroll{max-height:330px;overflow:auto}
    @media (max-width:950px){.two{grid-template-columns:1fr}}
  ` + '</style>';
  document.body.innerHTML = `
    <header><h1>📊 Tableau de bord Biblio-Tech</h1>
      <label>Du <input type="date" id="from"></label><label>au <input type="date" id="to"></label>
      <button data-d="1">Aujourd'hui</button><button data-d="7">7 j</button><button data-d="30">30 j</button><button data-d="90">90 j</button>
      <button class="pri" id="go">Actualiser</button><button id="xl" title="Classeur Excel avec graphiques et liens, enregistré dans Téléchargements">⬇ Exporter Excel</button><span id="st"></span></header>
    <main>
      <div class="kpis" id="kpis"></div>
      <div class="card"><h2>Commentaires par jour</h2>
        <div class="leg"><span><i style="background:#0088CE"></i>Commentaires</span><span><i style="background:#F59E0B"></i>Réponses</span></div><div id="chart"></div></div>
      <div class="card"><h2>📝 Commentaires sans réponse <span class="note" id="unote"></span></h2><div class="scroll" id="unans"></div></div>
      <div class="two">
        <div class="card"><h2>⭐ Consignes phares — les plus consultées</h2><p class="note" id="vnote"></p><div id="views"></div></div>
        <div class="card"><h2>💬 Pages les plus commentées</h2><div id="topc"></div></div>
      </div>
      <div class="card"><h2>✍️ Activité éditoriale</h2>
        <div class="leg"><span><i style="background:#22C55E"></i>Fiches créées</span><span><i style="background:#0088CE"></i>Fiches mises à jour (dernière modification)</span></div><div id="edit"></div></div>
      <div class="two">
        <div class="card"><h2>🆕 Nouvelles consignes</h2><div class="scroll" id="newp"></div></div>
        <div class="card"><h2>⚠️ Fiches à revoir — actives mais non mises à jour depuis 12 mois</h2><div class="scroll" id="stale"></div></div>
      </div>
      <div class="two">
        <div class="card"><h2>🗂️ Commentaires par rubrique</h2><div id="rub"></div></div>
        <div class="card"><h2>🕘 Jours et heures des commentaires</h2><div id="heat"></div></div>
      </div>
      <div class="two">
        <div class="card"><h2>❤️ Fiches les plus appréciées (J'aime)</h2><p class="note" id="lnote"></p><div id="likes"></div></div>
        <div class="card"><h2>👤 Contributeurs les plus actifs</h2><div id="topu"></div></div>
      </div>
    </main>`;

  var $ = function(id){ return document.getElementById(id); };
  var t0d = new Date(); $('from').value = ymd(addDays(t0d, -29)); $('to').value = ymd(t0d);
  Array.prototype.forEach.call(document.querySelectorAll('button[data-d]'), function(b){
    b.onclick = function(){ var n = +b.getAttribute('data-d'); var t = new Date(); $('to').value = ymd(t); $('from').value = ymd(addDays(t, -(n-1))); run(); };
  });
  $('go').onclick = function(){ run(); };
  var last = null;
  $('xl').onclick = function(){
    if (!last || !last.done) { $('st').textContent = 'Rien à exporter : attendez la fin du chargement.'; return; }
    $('st').textContent = 'Export Excel en cours…';
    log('EXPORT:' + JSON.stringify(last));
  };

  // ---------- rendus ----------
  function bars(list, max, link, suffix){
    if (!list || !list.length) return '<p class="note">Aucune donnée sur la période.</p>';
    return list.map(function(x){
      var w = Math.max(3, Math.round(100 * x.n / (max || 1)));
      var name = link && x.url ? '<a href="' + esc(x.url) + '" target="_blank" title="' + esc(x.k) + '">' + esc(x.k) + '</a>' : '<span class="k" title="' + esc(x.k) + '">' + esc(x.k) + '</span>';
      return '<div class="row">' + name + (suffix ? suffix(x) : '') + '<div><div class="bar" style="width:' + w + '%"></div></div><div class="num">' + x.n + '</div></div>';
    }).join('');
  }
  function topOf(map, n){ return Object.keys(map).map(function(k){ return map[k]; }).sort(function(a,b){ return b.n - a.n; }).slice(0, n); }
  function niceTop(max){
    var raw = Math.max(1, max) / 4, mag = Math.pow(10, Math.floor(Math.log10(raw)));
    var unit = [1, 2, 2.5, 5, 10].map(function(m){ return m * mag; }).filter(function(u){ return u >= raw && u >= 1 && (u % 1 === 0); })[0] || Math.ceil(raw);
    return unit * 4;
  }
  // Barres par jour : series = [{key, color}] ; stacked = empilées sinon côte à côte.
  function dayChart(days, series, stacked){
    var W = 1150, H = 230, L = 34, B = 26, T = 10, n = days.length;
    var max = Math.max.apply(null, days.map(function(d){ return stacked ? series.reduce(function(s, x){ return s + d[x.key]; }, 0) : Math.max.apply(null, series.map(function(x){ return d[x.key]; })); }));
    var top = niceTop(max), bw = (W - L - 6) / n, s = '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%" preserveAspectRatio="none" style="height:' + H + 'px">';
    for (var g = 0; g <= 4; g++) { var v = Math.round(top * g / 4), y = H - B - (H - B - T) * g / 4;
      s += '<line x1="' + L + '" x2="' + W + '" y1="' + y + '" y2="' + y + '" style="stroke:var(--line)"/><text x="' + (L-6) + '" y="' + (y+4) + '" text-anchor="end">' + v + '</text>'; }
    var every = Math.max(1, Math.ceil(n / 15));
    days.forEach(function(d, i){
      var x = L + 3 + i * bw, w = Math.max(1, bw - 2), acc = 0;
      var tip = '<title>' + d.label + ' : ' + series.map(function(z){ return d[z.key] + ' ' + z.name; }).join(', ') + '</title>';
      s += '<g>' + tip;
      series.forEach(function(z, k){
        var h = (H - B - T) * d[z.key] / top;
        if (stacked) { s += '<rect x="' + x + '" y="' + (H - B - acc - h) + '" width="' + w + '" height="' + h + '" fill="' + z.color + '" rx="2"/>'; acc += h; }
        else { var sw = w / series.length; s += '<rect x="' + (x + k * sw) + '" y="' + (H - B - h) + '" width="' + Math.max(1, sw - 1) + '" height="' + h + '" fill="' + z.color + '" rx="2"/>'; }
      });
      s += '<rect x="' + x + '" y="' + T + '" width="' + w + '" height="' + (H - B - T) + '" fill="transparent"/></g>';
      if (i % every === 0) s += '<text x="' + (x + w/2) + '" y="' + (H - 8) + '" text-anchor="middle">' + d.label.slice(0,5) + '</text>';
    });
    return s + '</svg>';
  }
  var PAL = ['#0088CE','#F59E0B','#22C55E','#A855F7','#EF4444','#14B8A6','#EAB308','#64748B'];
  function donut(list){
    if (!list.length) return '<p class="note">Aucune donnée.</p>';
    var tot = list.reduce(function(s, x){ return s + x.n; }, 0), a0 = -Math.PI / 2, cx = 110, cy = 110, R = 95, r = 58;
    var s = '<div style="display:flex;gap:18px;align-items:center;flex-wrap:wrap"><svg width="220" height="220" viewBox="0 0 220 220">';
    list.forEach(function(x, i){
      var a1 = a0 + 2 * Math.PI * x.n / tot, big = (a1 - a0) > Math.PI ? 1 : 0, c = PAL[i % PAL.length];
      if (list.length === 1) { s += '<circle cx="110" cy="110" r="76" fill="none" stroke="' + c + '" stroke-width="37"/>'; }
      else s += '<path d="M' + (cx + R*Math.cos(a0)) + ' ' + (cy + R*Math.sin(a0)) + ' A' + R + ' ' + R + ' 0 ' + big + ' 1 ' + (cx + R*Math.cos(a1)) + ' ' + (cy + R*Math.sin(a1))
        + ' L' + (cx + r*Math.cos(a1)) + ' ' + (cy + r*Math.sin(a1)) + ' A' + r + ' ' + r + ' 0 ' + big + ' 0 ' + (cx + r*Math.cos(a0)) + ' ' + (cy + r*Math.sin(a0)) + ' Z" fill="' + c + '"><title>' + esc(x.k) + ' : ' + x.n + '</title></path>';
      a0 = a1;
    });
    s += '<text x="110" y="106" text-anchor="middle" style="font-size:22px;fill:var(--txt)">' + tot + '</text><text x="110" y="126" text-anchor="middle">commentaires</text></svg><div>';
    list.forEach(function(x, i){ s += '<div style="padding:2px 0"><i style="display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px;background:' + PAL[i % PAL.length] + '"></i>' + esc(x.k) + ' <span class="num">' + x.n + ' (' + Math.round(100 * x.n / tot) + ' %)</span></div>'; });
    return s + '</div></div>';
  }
  var DOW = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
  function heatmap(h){
    var max = 1; h.forEach(function(r){ r.forEach(function(v){ if (v > max) max = v; }); });
    var cw = 22, ch = 22, L = 36, T = 18, s = '<svg viewBox="0 0 ' + (L + 24 * cw) + ' ' + (T + 7 * ch) + '" width="100%">';
    for (var hh = 0; hh < 24; hh += 2) s += '<text x="' + (L + hh * cw + cw/2) + '" y="12" text-anchor="middle">' + hh + 'h</text>';
    h.forEach(function(r, d){
      s += '<text x="' + (L - 6) + '" y="' + (T + d * ch + 15) + '" text-anchor="end">' + DOW[d] + '</text>';
      r.forEach(function(v, hh){
        var o = v ? 0.15 + 0.85 * v / max : 0.04;
        s += '<rect x="' + (L + hh * cw + 1) + '" y="' + (T + d * ch + 1) + '" width="' + (cw - 2) + '" height="' + (ch - 2) + '" rx="3" fill="#0088CE" fill-opacity="' + o.toFixed(2) + '"><title>' + DOW[d] + ' ' + hh + 'h : ' + v + ' commentaire(s)</title></rect>';
      });
    });
    return s + '</svg>';
  }
  function kpi(label, value, sub, cls){ return '<div class="kpi ' + (cls || '') + '"><span>' + label + '</span><b>' + value + '</b>' + (sub ? '<small>' + sub + '</small>' : '') + '</div>'; }
  function delta(cur, prev){
    if (prev === null || prev === undefined || cur === null) return '';
    if (!prev) return cur ? '<span class="up">nouveau vs période préc.</span>' : '';
    var p = Math.round(100 * (cur - prev) / prev);
    return '<span class="' + (p >= 0 ? 'up' : 'down') + '">' + (p >= 0 ? '+' : '') + p + ' %</span> vs période préc. (' + prev + ')';
  }
  function hours(x){ if (x === null || x === undefined) return '–'; return x < 48 ? Math.round(x) + ' h' : Math.round(x / 24 * 10) / 10 + ' j'; }

  function renderKpis(S){
    var k = S.k, h = '';
    h += kpi('Commentaires postés', k.comments, delta(k.comments, k.prevComments));
    h += kpi('dont réponses', k.replies, k.comments ? Math.round(100 * k.replies / k.comments) + ' % des commentaires' : '');
    h += kpi('Sans réponse', k.unanswered === null ? '…' : k.unanswered, k.questions ? 'sur ' + k.questions + ' question(s) de la période' : '', k.unanswered ? 'warn' : '');
    h += kpi('Délai médian 1re réponse', hours(k.medianH), k.avgH !== null && k.avgH !== undefined ? 'moyenne ' + hours(k.avgH) : '');
    h += kpi('Répondu en moins de 48 h', k.pct48 === null || k.pct48 === undefined ? '–' : k.pct48 + ' %', '');
    h += kpi('Pages commentées', k.pagesCommented, '');
    h += kpi('Contributeurs', k.users, '');
    h += kpi('Nouvelles fiches', k.created === null ? '…' : k.created, delta(k.created, k.prevCreated));
    h += kpi('Fiches mises à jour', k.updated === null ? '…' : k.updated, delta(k.updated, k.prevUpdated));
    h += kpi('Fiches > 12 mois sans mise à jour', k.stale12 === null ? '…' : k.stale12, 'sur l\'ensemble de la base', k.stale12 ? 'warn' : '');
    $('kpis').innerHTML = h;
  }

  // ---------- chargement ----------
  var runId = 0;
  function run(){
    var id = ++runId, from = $('from').value, to = $('to').value;
    if (!from || !to || from > to) { $('st').textContent = 'Plage de dates invalide.'; return; }
    var t0 = Date.now(), today = ymd(new Date());
    var toNext = ymd(addDays(D(to), 1)), nDays = Math.round((D(toNext) - D(from)) / 864e5);
    var pFrom = ymd(addDays(D(from), -nDays));            // période précédente de même durée
    var rng = function(f, t){ return ' >= "' + f + '" AND created < "' + t + '"'; };
    var S = { k: { comments: 0, replies: 0, questions: 0, unanswered: null, medianH: null, avgH: null, pct48: null, pagesCommented: 0, users: 0,
                   created: null, updated: null, stale12: null, prevComments: null, prevCreated: null, prevUpdated: null } };
    last = { done: false, from: from, to: to, base: base };
    var alive = function(){ return id === runId; };
    $('st').textContent = 'Chargement des commentaires…';
    var EXP = 'ancestors,container,history';
    var cqlC = 'type = comment AND created' + rng(from, toNext) + SPACE;

    searchAll(cqlC, EXP, P.max, function(n, tot){ if (alive()) $('st').textContent = 'Chargement des commentaires… ' + n + (tot ? ' / ' + tot : ''); })
    .then(function(all){
      if (!alive()) return;
      // Réponses postées APRÈS la période (pour savoir si une question a eu une réponse).
      var later = (toNext <= today) ? searchAll('type = comment AND created >= "' + toNext + '"' + SPACE, EXP, P.max) : Promise.resolve([]);
      return later.catch(function(){ return []; }).then(function(after){ return { all: all, after: after }; });
    })
    .then(function(R){
      if (!R || !alive()) return;
      var all = R.all, dayMap = {}, pages = {}, users = {}, heat = [], nReply = 0;
      for (var i = 0; i < 7; i++) { heat.push([]); for (var j = 0; j < 24; j++) heat[i].push(0); }
      for (var d = D(from); ymd(d) <= to; d = addDays(d, 1)) dayMap[ymd(d)] = { c:0, r:0, cr:0, up:0, label: fr(ymd(d)) };
      var cAnc = function(c){ return (c.ancestors || []).filter(function(a){ return a.type === 'comment'; }); };
      var qs = {};      // questions (commentaires de 1er niveau) de la période
      all.forEach(function(c){
        var h = c.history || {}, when = txt(h.createdDate), day = when.slice(0, 10), isReply = cAnc(c).length > 0;
        var by = txt(h.createdBy && (h.createdBy.displayName || h.createdBy.username));
        if (isReply) nReply++;
        if (dayMap[day]) { if (isReply) dayMap[day].r++; else dayMap[day].c++; }
        var dt = new Date(when); if (!isNaN(dt)) heat[(dt.getDay() + 6) % 7][dt.getHours()]++;
        var ct = c.container || {}, pk = txt(ct.id || ct.title), purl = ct._links && ct._links.webui ? base + ct._links.webui : '';
        if (pk) { pages[pk] = pages[pk] || { id: txt(ct.id), k: txt(ct.title), n:0, url: purl }; pages[pk].n++; }
        if (by) { users[by] = users[by] || { k: by, n:0 }; users[by].n++; }
        if (!isReply) qs[c.id] = { id: c.id, k: txt(ct.title), page: purl, url: purl ? purl + (purl.indexOf('?') < 0 ? '?' : '&') + 'focusedCommentId=' + c.id + '#comment-' + c.id : '', by: by, when: when, first: null };
      });
      // 1re réponse d'un AUTRE contributeur à chaque question.
      all.concat(R.after).forEach(function(c){
        var anc = cAnc(c); if (!anc.length) return;
        var q = qs[anc[0].id]; if (!q) return;
        var h = c.history || {}, by = txt(h.createdBy && (h.createdBy.displayName || h.createdBy.username));
        if (by && by === q.by) return;
        var t = new Date(txt(h.createdDate)); if (isNaN(t)) return;
        if (!q.first || t < q.first) q.first = t;
      });
      var ql = Object.keys(qs).map(function(k){ return qs[k]; }), delays = [], now = new Date(), un = [];
      ql.forEach(function(q){
        if (q.first) delays.push((q.first - new Date(q.when)) / 36e5);
        else un.push({ k: q.k, url: q.url, by: q.by, date: q.when.slice(0, 10), age: Math.floor((now - new Date(q.when)) / 864e5) });
      });
      delays.sort(function(a, b){ return a - b; });
      un.sort(function(a, b){ return b.age - a.age; });
      var k = S.k;
      k.comments = all.length; k.replies = nReply; k.questions = ql.length; k.unanswered = un.length;
      k.medianH = delays.length ? delays[Math.floor(delays.length / 2)] : null;
      k.avgH = delays.length ? delays.reduce(function(s, x){ return s + x; }, 0) / delays.length : null;
      k.pct48 = ql.length ? Math.round(100 * delays.filter(function(x){ return x <= 48; }).length / ql.length) : null;
      k.pagesCommented = Object.keys(pages).length; k.users = Object.keys(users).length;
      S.days = Object.keys(dayMap).sort().map(function(x){ return dayMap[x]; });
      S.pages = pages; S.users = users; S.heat = heat; S.un = un;
      renderKpis(S);
      $('chart').innerHTML = dayChart(S.days, [{key:'c', name:'commentaire(s)', color:'#0088CE'}, {key:'r', name:'réponse(s)', color:'#F59E0B'}], true);
      $('unote').textContent = un.length ? '— ' + un.length + ' en attente (les plus anciennes en premier)' : '';
      $('unans').innerHTML = un.length ? '<table><tr><th>Fiche</th><th>Auteur</th><th>Posté le</th><th>En attente</th></tr>' + un.slice(0, 100).map(function(u){
          return '<tr><td><a href="' + esc(u.url) + '" target="_blank" title="' + esc(u.k) + '">' + esc(u.k) + '</a></td><td>' + esc(u.by) + '</td><td>' + fr(u.date) + '</td><td>' + (u.age >= 7 ? '<span class="tag">' + u.age + ' j</span>' : u.age + ' j') + '</td></tr>'; }).join('') + '</table>'
        : '<p class="note">Toutes les questions de la période ont reçu une réponse. 👍</p>';
      var tp = topOf(pages, 12); S.tp = tp;
      $('topc').innerHTML = bars(tp, tp.length ? tp[0].n : 1, true);
      var tu = topOf(users, 12); $('topu').innerHTML = bars(tu, tu.length ? tu[0].n : 1, false);
      $('heat').innerHTML = heatmap(heat);
      $('st').textContent = all.length + ' commentaire(s) · chargement des indicateurs complémentaires…';
      log('[DASH] ' + from + '..' + to + ' : ' + all.length + ' commentaire(s), ' + nReply + ' réponse(s), ' + ql.length + ' question(s), ' + un.length + ' sans réponse, ' + k.pagesCommented + ' page(s)');
      return Promise.all([ editorial(S, from, toNext, pFrom), rubriques(S), views(from, to), likes(tp, S) ]).then(function(res){
        if (!alive()) return;
        var v = res[2], lk = res[3];
        // Consignes phares.
        if (v && v.length) { $('vnote').textContent = 'Source : statistiques de consultation Confluence.'; $('views').innerHTML = bars(v.slice(0, 12), v[0].n, true); S.views = v.slice(0, 50); S.viewsSource = 'Consultations (statistiques Confluence)'; }
        else {
          $('vnote').textContent = 'Statistiques de consultation indisponibles via l\'API sur cette instance (calibrage en cours) : en attendant, pages les plus commentées sur la période.';
          $('views').innerHTML = bars(tp.slice(0, 8), tp.length ? tp[0].n : 1, true); S.views = tp.slice(0, 8); S.viewsSource = 'Commentaires (consultations indisponibles via l\'API)';
        }
        // J'aime.
        if (lk) {
          var ll = lk.filter(function(x){ return x.n > 0; }).sort(function(a, b){ return b.n - a.n; });
          $('lnote').textContent = 'Parmi les fiches les plus commentées de la période.';
          $('likes').innerHTML = bars(ll, ll.length ? ll[0].n : 1, true); S.likes = ll;
        } else { $('lnote').textContent = 'Nombre de « J\'aime » indisponible via l\'API sur cette instance.'; $('likes').innerHTML = ''; S.likes = []; }
        // Fiches à revoir : actives (commentées / consultées) et non modifiées depuis 12 mois.
        var lim = addDays(new Date(), -365), stale = [];
        Object.keys(S.pages).forEach(function(pk){ var p = S.pages[pk], m = S.meta[p.id]; if (m && m.lu && new Date(m.lu) < lim) stale.push({ k: p.k, url: p.url, n: p.n, lu: m.lu.slice(0, 10) }); });
        stale.sort(function(a, b){ return b.n - a.n; }); S.stale = stale;
        $('stale').innerHTML = stale.length ? '<table><tr><th>Fiche</th><th>Dernière mise à jour</th><th>Commentaires</th></tr>' + stale.slice(0, 60).map(function(s){
            return '<tr><td><a href="' + esc(s.url) + '" target="_blank" title="' + esc(s.k) + '">' + esc(s.k) + '</a></td><td><span class="tag">' + fr(s.lu) + '</span></td><td>' + s.n + '</td></tr>'; }).join('') + '</table>'
          : '<p class="note">Aucune fiche active de la période n\'a plus de 12 mois sans mise à jour. 👍</p>';
        renderKpis(S);
        var k = S.k;
        last = { done: true, from: from, to: to, base: base, truncated: all.length >= P.max, k: k,
          days: S.days.map(function(d){ return { d: d.label, c: d.c, r: d.r, cr: d.cr, up: d.up }; }),
          unanswered: S.un.slice(0, 500), topPages: topOf(S.pages, 100).map(function(p){ var m = S.meta[p.id] || {}; return { k: p.k, n: p.n, url: p.url, lu: txt(m.lu).slice(0, 10), rub: m.rub || '', likes: (S.likesMap || {})[p.id] }; }),
          topUsers: topOf(S.users, 100), views: S.views, viewsSource: S.viewsSource, likes: S.likes,
          newPages: S.newPages || [], stale: S.stale, rubriques: S.rub || [], heat: S.heat };
        $('st').textContent = all.length + ' commentaire(s) du ' + fr(from) + ' au ' + fr(to) + (all.length >= P.max ? ' (limite atteinte)' : '') + ' · ' + Math.round((Date.now() - t0) / 100) / 10 + ' s';
      });
    }).catch(function(e){
      if (!alive()) return;
      $('st').textContent = 'Erreur : ' + e.message;
      log('[DASH] Échec du chargement : ' + e.message);
    });
  }

  // Activité éditoriale + comparaisons + fiches > 12 mois (comptages).
  function editorial(S, from, toNext, pFrom){
    var k = S.k, TYPES = 'type in (page, blogpost)';
    var cqlNew = TYPES + ' AND created >= "' + from + '" AND created < "' + toNext + '"' + SPACE;
    var cqlUpd = TYPES + ' AND lastmodified >= "' + from + '" AND lastmodified < "' + toNext + '"' + SPACE;
    return Promise.all([
      searchAll(cqlNew, 'history,ancestors', 1000).catch(function(e){ log('[DASH] nouvelles fiches -> ' + e.message); return []; }),
      searchAll(cqlUpd, 'version', 2000).catch(function(e){ log('[DASH] fiches mises à jour -> ' + e.message); return []; }),
      count('type = comment AND created >= "' + pFrom + '" AND created < "' + from + '"' + SPACE),
      count(TYPES + ' AND created >= "' + pFrom + '" AND created < "' + from + '"' + SPACE),
      count(TYPES + ' AND lastmodified >= "' + pFrom + '" AND lastmodified < "' + from + '"' + SPACE),
      count('type = page AND lastmodified < now("-52w")' + SPACE)
    ]).then(function(r){
      var dm = {}; S.days.forEach(function(d){ dm[d.label] = d; });
      r[0].forEach(function(p){ var d = dm[fr(txt(p.history && p.history.createdDate).slice(0, 10))]; if (d) d.cr++; });
      r[1].forEach(function(p){ var d = dm[fr(txt(p.version && p.version.when).slice(0, 10))]; if (d) d.up++; });
      k.created = r[0].length; k.updated = r[1].length; k.prevComments = r[2]; k.prevCreated = r[3]; k.prevUpdated = r[4]; k.stale12 = r[5];
      S.newPages = r[0].map(function(p){ var h = p.history || {}, a = (p.ancestors || []).map(function(x){ return txt(x.title); });
        return { k: txt(p.title), url: p._links && p._links.webui ? base + p._links.webui : '', by: txt(h.createdBy && h.createdBy.displayName), date: txt(h.createdDate).slice(0, 10), rub: a.length > 1 ? a[1] : (a[0] || '') }; })
        .sort(function(a, b){ return a.date < b.date ? 1 : -1; });
      $('edit').innerHTML = dayChart(S.days, [{key:'cr', name:'fiche(s) créée(s)', color:'#22C55E'}, {key:'up', name:'fiche(s) mise(s) à jour', color:'#0088CE'}], false);
      $('newp').innerHTML = S.newPages.length ? '<table><tr><th>Fiche</th><th>Rubrique</th><th>Auteur</th><th>Créée le</th></tr>' + S.newPages.slice(0, 100).map(function(p){
          return '<tr><td><a href="' + esc(p.url) + '" target="_blank" title="' + esc(p.k) + '">' + esc(p.k) + '</a></td><td>' + esc(p.rub) + '</td><td>' + esc(p.by) + '</td><td>' + fr(p.date) + '</td></tr>'; }).join('') + '</table>'
        : '<p class="note">Aucune nouvelle fiche sur la période.</p>';
      log('[DASH] éditorial : ' + k.created + ' créée(s), ' + k.updated + ' mise(s) à jour, ' + k.stale12 + ' fiche(s) > 12 mois ; période préc. : ' + k.prevComments + ' comm., ' + k.prevCreated + ' créées');
      renderKpis(S);
    });
  }

  // Rubrique (page parente de niveau 1) et date de dernière mise à jour des pages commentées.
  function rubriques(S){
    var ids = Object.keys(S.pages).map(function(k){ return S.pages[k].id; }).filter(function(x){ return x; }), chunks = [];
    S.meta = {};
    for (var i = 0; i < ids.length && i < 600; i += 40) chunks.push(ids.slice(i, i + 40));
    return chunks.reduce(function(p, ch){
      return p.then(function(){
        return searchAll('id in (' + ch.join(',') + ')', 'ancestors,version', 60).then(function(res){
          res.forEach(function(c){ var a = (c.ancestors || []).map(function(x){ return txt(x.title); });
            S.meta[txt(c.id)] = { rub: a.length > 1 ? a[1] : txt(c.title), lu: txt(c.version && c.version.when) }; });   // a[0] = accueil de l'espace
        });
      });
    }, Promise.resolve()).catch(function(e){ log('[DASH] rubriques -> ' + e.message); }).then(function(){
      var m = {};
      Object.keys(S.pages).forEach(function(pk){ var p = S.pages[pk], r = (S.meta[p.id] || {}).rub || '(non classée)'; m[r] = (m[r] || 0) + p.n; });
      var list = Object.keys(m).map(function(k){ return { k: k, n: m[k] }; }).sort(function(a, b){ return b.n - a.n; });
      if (list.length > 8) { var rest = list.slice(7).reduce(function(s, x){ return s + x.n; }, 0); list = list.slice(0, 7).concat([{ k: 'Autres', n: rest }]); }
      S.rub = list;
      $('rub').innerHTML = donut(list);
    });
  }

  // « J'aime » des fiches les plus commentées (API Likes ; absente sur certaines instances).
  function likes(tp, S){
    var top = tp.slice(0, 12).filter(function(p){ return p.id; });
    if (!top.length) return Promise.resolve([]);
    var map = {};
    return Promise.all(top.map(function(p){
      return get('/rest/likes/1.0/content/' + p.id + '/likes').then(function(j){
        var n = Array.isArray(j) ? j.length : (j.likes ? j.likes.length : (+j.count || 0)); map[p.id] = n; return { k: p.k, url: p.url, n: n };
      });
    })).then(function(r){ S.likesMap = map; log('[DASH] J\'aime : API OK (' + r.length + ' fiche(s))'); return r; },
      function(e){ log('[DASH] J\'aime -> ' + e.message); return null; });
  }

  // Consultations : essais d'API Confluence Analytics (journalisés pour calibrage).
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
        return { k: k, n: n, url: u ? (/^https?:/.test(u) ? u : base + u) : '' };
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

  run();
  return 'ok';
})(__P__)
'@

# --- Export Excel (COM : Excel déjà installé sur le poste, aucun .exe livré) ---------
# Synthèse (indicateurs + graphiques natifs) puis une feuille par indicateur ; titres de
# fiches = liens cliquables vers Confluence.
function New-BtDashboardWorkbook {
    param($Data, [string]$Path, [string]$Version = '')
    $xl = $null; $wb = $null
    $sheets = @('Synthèse', 'Par jour', 'Sans réponse', 'Pages commentées', 'Consignes phares', 'Nouvelles consignes',
        'Fiches à revoir', 'Rubriques', 'Jours-heures', 'J''aime', 'Contributeurs')
    try {
        $xl = New-Object -ComObject Excel.Application
        $xl.Visible = $false; $xl.DisplayAlerts = $false; $xl.ScreenUpdating = $false
        $wb = $xl.Workbooks.Add()
        while ($wb.Worksheets.Count -lt $sheets.Count) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
        for ($i = 1; $i -le $sheets.Count; $i++) { $wb.Worksheets.Item($i).Name = $sheets[$i - 1] }
        $S = @{}; for ($i = 1; $i -le $sheets.Count; $i++) { $S[$sheets[$i - 1]] = $wb.Worksheets.Item($i) }
        $newList = { New-Object 'System.Collections.Generic.List[object[]]' }   # (≠ $l : PowerShell ignore la casse)
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
        $one = { param($ws, [int]$r, [int]$c, $v) $l = & $newList; $l.Add([object[]]@($v)); & $put $ws $r $c $l }
        $head = {
            param($ws, [string[]]$cols, [int[]]$widths)
            $l = & $newList; $l.Add([object[]]$cols); & $put $ws 1 1 $l
            $h = $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item(1, $cols.Count))
            $h.Font.Bold = $true; $h.Font.Color = 0xFFFFFF; $h.Interior.Color = 0xCE8800   # BGR : bleu #0088CE
            for ($c = 0; $c -lt $widths.Count; $c++) { $ws.Columns.Item($c + 1).ColumnWidth = $widths[$c] }
        }
        # Via COM depuis PowerShell, Excel lit NumberFormat dans la langue de l'utilisateur
        # (« jj/mm/aaaa » en français, « dd/mm/yyyy » en anglais) : on essaie les deux.
        $dateFmt = { param($rng) foreach ($f in @('jj/mm/aaaa', 'dd/mm/yyyy', 'tt.mm.jjjj')) { try { $rng.NumberFormat = $f; break } catch { } } }
        $oa = {
            param([string]$s)
            if (-not $s) { return '' }
            foreach ($f in @('yyyy-MM-dd', 'dd/MM/yyyy')) { try { return [datetime]::ParseExact($s.Substring(0, 10), $f, [Globalization.CultureInfo]::InvariantCulture).ToOADate() } catch { } }
            return $s
        }
        $link = { param($ws, [int]$r, [int]$c, [string]$url, [string]$t) if ($url) { try { [void]$ws.Hyperlinks.Add($ws.Cells.Item($r, $c), $url, '', $url, $t) } catch { } } }
        $num = { param($v) if ($null -eq $v -or "$v" -eq '') { '' } else { [double]$v } }

        # --- Par jour.
        $ws = $S['Par jour']
        & $head $ws @('Date', 'Commentaires', 'Réponses', 'Total commentaires', 'Fiches créées', 'Fiches mises à jour') @(14, 15, 12, 19, 15, 20)
        $l = & $newList; $r = 2
        foreach ($d in @($Data.days)) { $l.Add([object[]]@((& $oa ([string]$d.d)), [double]$d.c, [double]$d.r, "=B$r+C$r", (& $num $d.cr), (& $num $d.up))); $r++ }
        & $put $ws 2 1 $l; $lastDay = $r - 1
        if ($lastDay -ge 2) { & $dateFmt $ws.Range("A2:A$lastDay") }

        # --- Sans réponse.
        $ws = $S['Sans réponse']
        & $head $ws @('Fiche', 'Auteur', 'Posté le', 'En attente (jours)') @(70, 26, 14, 18)
        $ws.Columns.Item(1).NumberFormat = '@'
        $l = & $newList; foreach ($u in @($Data.unanswered)) { $l.Add([object[]]@([string]$u.k, [string]$u.by, (& $oa ([string]$u.date)), [double]$u.age)) }
        & $put $ws 2 1 $l
        $r = 2; foreach ($u in @($Data.unanswered)) { & $link $ws $r 1 ([string]$u.url) ([string]$u.k); $r++ }
        $nUn = $r - 1
        if ($nUn -ge 2) { & $dateFmt $ws.Range("C2:C$nUn") }

        # --- Pages commentées.
        $ws = $S['Pages commentées']
        & $head $ws @('Fiche', 'Commentaires', 'J''aime', 'Rubrique', 'Dernière mise à jour') @(70, 15, 10, 30, 20)
        $ws.Columns.Item(1).NumberFormat = '@'
        $l = & $newList; foreach ($p in @($Data.topPages)) { $l.Add([object[]]@([string]$p.k, [double]$p.n, (& $num $p.likes), [string]$p.rub, (& $oa ([string]$p.lu)))) }
        & $put $ws 2 1 $l
        $r = 2; foreach ($p in @($Data.topPages)) { & $link $ws $r 1 ([string]$p.url) ([string]$p.k); $r++ }
        $nP = $r - 1
        if ($nP -ge 2) { & $dateFmt $ws.Range("E2:E$nP") }

        # --- Listes simples {k, n, url}.
        $simple = {
            param($ws, $rows, [string]$label, [string]$numLabel)
            & $head $ws @($label, $numLabel) @(70, 16)
            $ws.Columns.Item(1).NumberFormat = '@'          # texte (un titre « =… » n'est pas une formule)
            $l = & $newList; foreach ($x in @($rows)) { $l.Add([object[]]@([string]$x.k, [double]$x.n)) }
            & $put $ws 2 1 $l
            $r = 2; foreach ($x in @($rows)) { & $link $ws $r 1 ([string]$x.url) ([string]$x.k); $r++ }
            return ($r - 1)
        }
        $isViews = ([string]$Data.viewsSource) -like 'Consultations*'
        $nV = & $simple $S['Consignes phares'] $Data.views 'Consigne / fiche' $(if ($isViews) { 'Consultations' } else { 'Commentaires' })
        & $one $S['Consignes phares'] ($nV + 2) 1 "Source : $($Data.viewsSource)"
        $nL = & $simple $S['J''aime'] $Data.likes 'Fiche' 'J''aime'
        $nU = & $simple $S['Contributeurs'] $Data.topUsers 'Contributeur' 'Commentaires'
        $nR = & $simple $S['Rubriques'] $Data.rubriques 'Rubrique' 'Commentaires'

        # --- Nouvelles consignes.
        $ws = $S['Nouvelles consignes']
        & $head $ws @('Fiche', 'Rubrique', 'Auteur', 'Créée le') @(70, 30, 26, 14)
        $ws.Columns.Item(1).NumberFormat = '@'
        $l = & $newList; foreach ($p in @($Data.newPages)) { $l.Add([object[]]@([string]$p.k, [string]$p.rub, [string]$p.by, (& $oa ([string]$p.date)))) }
        & $put $ws 2 1 $l
        $r = 2; foreach ($p in @($Data.newPages)) { & $link $ws $r 1 ([string]$p.url) ([string]$p.k); $r++ }
        if ($r - 1 -ge 2) { & $dateFmt $ws.Range("D2:D$($r - 1)") }

        # --- Fiches à revoir.
        $ws = $S['Fiches à revoir']
        & $head $ws @('Fiche', 'Dernière mise à jour', 'Commentaires sur la période') @(70, 20, 26)
        $ws.Columns.Item(1).NumberFormat = '@'
        $l = & $newList; foreach ($p in @($Data.stale)) { $l.Add([object[]]@([string]$p.k, (& $oa ([string]$p.lu)), [double]$p.n)) }
        & $put $ws 2 1 $l
        $r = 2; foreach ($p in @($Data.stale)) { & $link $ws $r 1 ([string]$p.url) ([string]$p.k); $r++ }
        if ($r - 1 -ge 2) { & $dateFmt $ws.Range("B2:B$($r - 1)") }

        # --- Jours × heures (échelle de couleurs).
        $ws = $S['Jours-heures']
        $hdr = [object[]](@('') + (0..23 | ForEach-Object { "$($_)h" }))
        $l = & $newList; $l.Add($hdr)
        $dow = @('Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche')
        $hm = @($Data.heat)
        for ($d = 0; $d -lt 7; $d++) { $row = @($dow[$d]); for ($h = 0; $h -lt 24; $h++) { $row += [double]$(if ($hm.Count -gt $d) { @($hm[$d])[$h] } else { 0 }) }; $l.Add([object[]]$row) }
        & $put $ws 1 1 $l
        $ws.Range('A1:Y1').Font.Bold = $true; $ws.Range('A1:A8').Font.Bold = $true
        $ws.Columns.Item(1).ColumnWidth = 12
        try { [void]$ws.Range('B2:Y8').FormatConditions.AddColorScale(2) } catch { }

        # --- Synthèse : indicateurs + graphiques natifs.
        $ws = $S['Synthèse']
        $k = $Data.k
        & $one $ws 1 1 'Tableau de bord Biblio-Tech'
        $ws.Cells.Item(1, 1).Font.Size = 18; $ws.Cells.Item(1, 1).Font.Bold = $true
        & $one $ws 2 1 ("Période du $($Data.from) au $($Data.to)  ·  extrait le $(Get-Date -Format 'dd/MM/yyyy HH:mm')" + $(if ($Version) { "  ·  Biblio-Tech $Version" } else { '' }))
        $ws.Cells.Item(2, 1).Font.Color = 0x808080
        $hrs = { param($v) if ($null -eq $v -or "$v" -eq '') { '–' } elseif ([double]$v -lt 48) { '{0:N0} h' -f [double]$v } else { '{0:N1} j' -f ([double]$v / 24) } }
        $pct = { param($cur, $prev) if ($null -eq $prev -or "$prev" -eq '' -or [double]$prev -eq 0) { '' } else { '{0:+0;-0} % vs période préc.' -f (100 * ([double]$cur - [double]$prev) / [double]$prev) } }
        $kp = & $newList
        $kp.Add([object[]]@('Commentaires postés', 'dont réponses', 'Sans réponse', 'Délai médian 1re réponse', 'Répondu < 48 h'))
        $kp.Add([object[]]@([double]$k.comments, [double]$k.replies, (& $num $k.unanswered), (& $hrs $k.medianH), $(if ($null -ne $k.pct48) { "$($k.pct48) %" } else { '–' })))
        $kp.Add([object[]]@((& $pct $k.comments $k.prevComments), '', $(if ($k.questions) { "sur $($k.questions) question(s)" } else { '' }), '', ''))
        $kp.Add([object[]]@('', '', '', '', ''))
        $kp.Add([object[]]@('Pages commentées', 'Contributeurs', 'Nouvelles fiches', 'Fiches mises à jour', 'Fiches > 12 mois sans MAJ'))
        $kp.Add([object[]]@([double]$k.pagesCommented, [double]$k.users, (& $num $k.created), (& $num $k.updated), (& $num $k.stale12)))
        $kp.Add([object[]]@('', '', (& $pct $k.created $k.prevCreated), (& $pct $k.updated $k.prevUpdated), 'sur toute la base'))
        & $put $ws 4 1 $kp
        foreach ($rr in @(4, 8)) { $ws.Range("A$($rr):E$($rr)").Font.Color = 0x808080 }
        foreach ($rr in @(5, 9)) { $g = $ws.Range("A$($rr):E$($rr)"); $g.Font.Size = 20; $g.Font.Bold = $true; $g.HorizontalAlignment = -4131 }
        foreach ($rr in @(6, 10)) { $ws.Range("A$($rr):E$($rr)").Font.Color = 0x808080; $ws.Range("A$($rr):E$($rr)").Font.Italic = $true }
        foreach ($c in 1..10) { $ws.Columns.Item($c).ColumnWidth = 24 }
        if ($Data.truncated) { & $one $ws 11 1 '(limite de chargement atteinte : chiffres partiels)' }
        & $one $ws 12 1 'Ouvrir Biblio-Tech (Confluence)'
        & $link $ws 12 1 ([string]$Data.base) 'Ouvrir Biblio-Tech (Confluence)'

        $top = $ws.Rows.Item(14).Top
        $chart = {
            param([int]$type, $src, [string]$title, [double]$x, [double]$y, [double]$w, [double]$h, [bool]$legend, [bool]$reverse)
            $co = $ws.ChartObjects().Add($x, $y, $w, $h); $ch = $co.Chart
            $ch.ChartType = $type; $ch.SetSourceData($src)
            $ch.HasTitle = $true; $ch.ChartTitle.Text = $title; $ch.HasLegend = $legend
            if ($reverse) { try { $ch.Axes(1).ReversePlotOrder = $true } catch { } }
            return $ch
        }
        if ($lastDay -ge 2) {
            $ch = & $chart 52 $S['Par jour'].Range("A1:C$lastDay") 'Commentaires par jour' 5 $top 900 260 $true $false   # xlColumnStacked
            try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0xCE8800; $ch.SeriesCollection(2).Format.Fill.ForeColor.RGB = 0x0B9EF5 } catch { }
            $top += 270
            # Colonnes non contiguës (dates + E:F) : séparateur de plages dépendant de la langue et
            # Union inaccessible via COM -> source E:F puis axe des dates posé sur chaque série.
            $ch = & $chart 51 $S['Par jour'].Range("E1:F$lastDay") 'Activité éditoriale (fiches créées / mises à jour)' 5 $top 900 240 $true $false   # xlColumnClustered
            foreach ($si in 1, 2) { try { $ch.SeriesCollection($si).XValues = $S['Par jour'].Range("A2:A$lastDay") } catch { } }
            try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0x5EC522; $ch.SeriesCollection(2).Format.Fill.ForeColor.RGB = 0xCE8800 } catch { }
            $top += 250
        }
        if ($nV -ge 2) { $ch = & $chart 57 $S['Consignes phares'].Range("A1:B$([Math]::Min($nV, 11))") 'Consignes phares' 5 $top 445 300 $false $true; try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0x0B9EF5 } catch { } }
        if ($nP -ge 2) { $ch = & $chart 57 $S['Pages commentées'].Range("A1:B$([Math]::Min($nP, 11))") 'Pages les plus commentées' 460 $top 445 300 $false $true; try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0xCE8800 } catch { } }
        $top += 310
        if ($nR -ge 2) { [void](& $chart -4120 $S['Rubriques'].Range("A1:B$nR") 'Commentaires par rubrique' 5 $top 445 300 $true $false) }   # xlDoughnut
        if ($nL -ge 2) { $ch = & $chart 57 $S['J''aime'].Range("A1:B$([Math]::Min($nL, 11))") 'Fiches les plus appréciées (J''aime)' 460 $top 445 300 $false $true; try { $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0x4444EF } catch { } }
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
            Set-BtWebTheme $script:Ctx $s           # la page suit le thème Windows (prefers-color-scheme)
            # Liens des listes -> navigateur par défaut.
            $cw.add_NewWindowRequested({ param($a, $b) $b.Handled = $true; Open-BtExternal ([string]$b.Uri) })
            # Diagnostics remontés par la page -> journal de l'appli ; demande d'export Excel.
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
