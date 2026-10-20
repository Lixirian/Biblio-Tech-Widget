# ============================================================================
#  Accueil en TUILES (page de référence : « Bienvenue dans votre Biblio-TECH »,
#  Config.HomePageId).
#    - Accès rapides : dernières news (blogs de l'espace de l'accueil), nouvelles
#      consignes, plus commentées, mises à jour récentes, page d'accueil.
#    - Rubriques : les sous-pages de la page d'accueil, lues dans Confluence (les
#      tuiles suivent donc la structure réelle du site, sans liste codée en dur).
#  Clic sur une tuile -> « page suivante » dans la fenêtre (pile $Ctx.Home.Nav) :
#  sous-rubriques en tuiles, consignes en cartes. Une rubrique sans sous-page
#  s'ouvre directement dans le lecteur. Retour : bouton ←, Échap, bouton « précédent »
#  de la souris, onglet « Accueil ».
#  Données : sondes kick -> poll (window.__btHome / window.__btKids).
# ============================================================================

# --- JS : aperçu de l'accueil (rubriques, news, nouvelles consignes, plus commentées) ---
$script:BtHomeJs = @'
(function(P){
  window.__btHome = {state:'PENDING', id:P.id};
  var t0 = Date.now(), base = P.base, errs = [];
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
  // Une partie en échec n'empêche pas d'afficher les autres (sauf session expirée).
  function soft(name, p, dflt){ return p.catch(function(e){ if (e && e.auth) throw e; errs.push(name + ': ' + txt(e && e.message)); return dflt; }); }
  function item(c){
    var h = c.history || {}, lu = h.lastUpdated || {}, l = [], k = 0;
    try { (c.metadata.labels.results || []).forEach(function(x){ l.push(x.name); }); } catch(e){}
    try { var cp = c.children.page; k = (typeof cp.size === 'number') ? cp.size : (cp.results || []).length; } catch(e){}
    return { id:txt(c.id), type:txt(c.type || 'page'), title:txt(c.title), excerpt:'', url: c._links && c._links.webui ? base + c._links.webui : '',
             space:txt(c.space && c.space.name), spaceKey:txt(c.space && c.space.key), parent:'', modified:txt(lu.when || h.createdDate), friendly:'',
             author:txt((lu.by && lu.by.displayName) || (h.createdBy && h.createdBy.displayName)), labels:l, kids:k };
  }
  var home = P.homeId ? soft('accueil', get('/rest/api/content/' + P.homeId + '?expand=space'), null) : Promise.resolve(null);
  var rubrics = P.homeId ? soft('rubriques', get('/rest/api/content/' + P.homeId + '/child/page?limit=100&expand='
      + encodeURIComponent('children.page,space,history.lastUpdated')).then(function(j){ return (j.results || []).map(item); }), []) : Promise.resolve([]);
  var news = home.then(function(h){
    var sk = P.space || (h && h.space && h.space.key) || '';
    var cql = 'type = blogpost' + (sk ? ' AND space = "' + sk + '"' : '') + ' ORDER BY created DESC';
    return soft('news', get('/rest/api/content/search?cql=' + encodeURIComponent(cql) + '&limit=' + P.news
      + '&expand=' + encodeURIComponent('space,history,metadata.labels')).then(function(j){ return (j.results || []).map(item); }), []);
  });
  var SP = P.space ? ' AND space = "' + P.space + '"' : '';
  // Consignes (pages) les plus commentées : les commentaires de blogs/pièces jointes sont ignorés.
  var top = soft('commentées', all('type = comment AND created >= now("-' + P.days + 'd")' + SP, 'container,space', 1000).then(function(cs){
    var m = {};
    cs.forEach(function(c){
      var ct = c.container || {}, k = txt(ct.id); if (!k || (ct.type && ct.type !== 'page')) return;
      if (!m[k]) m[k] = { id:k, type:'page', title:txt(ct.title), excerpt:'', url: ct._links && ct._links.webui ? base + ct._links.webui : '',
                          space:txt(c.space && c.space.name), spaceKey:txt(c.space && c.space.key), parent:'', modified:'', friendly:'', author:'', labels:[], n:0 };
      m[k].n++;
    });
    return Object.keys(m).map(function(k){ return m[k]; }).sort(function(a, b){ return b.n - a.n; }).slice(0, P.top);
  }), []);
  var fresh = soft('nouvelles', get('/rest/api/content/search?cql=' + encodeURIComponent('type = page AND created >= now("-' + P.days + 'd")' + SP + ' ORDER BY created DESC')
      + '&limit=' + P.top + '&expand=' + encodeURIComponent('space,history,metadata.labels')).then(function(j){ return (j.results || []).map(item); }), []);
  // MISE EN PAGE de l'accueil TELLE QUE L'UTILISATEUR LA VOIT (les blocs dépendent de son
  // profil : « TAM / Gestionnaire en Production »…) : encadrés « mis en avant » (macro panel)
  // et sections « titre + liens ». Source 1 : la page d'accueil réellement affichée dans ce
  // WebView (rendu final, éléments masqués exclus) ; source 2 : body.view (rendu serveur
  // pour l'utilisateur connecté).
  function clean(v){ return txt(v).replace(/\s+/g, ' ').trim(); }
  function emojiOf(img){
    if (!img) return '';
    var f = txt(img.getAttribute('data-emoji-fallback'));
    if (f && f.charAt(0) !== ':') return f;
    var id = txt(img.getAttribute('data-emoji-id'));
    if (/^[0-9a-f]+(-[0-9a-f]+)*$/i.test(id)) { try { return id.split('-').map(function(h){ return String.fromCodePoint(parseInt(h, 16)); }).join(''); } catch(e){} }
    return '';
  }
  function layoutOf(root, live){
    var bh = new URL(base).host;
    function vis(el){ return !live || !!(el.offsetParent || el.getClientRects().length); }
    function linkOf(a){
      var href = txt(a.getAttribute('href'));
      if (!href || href.charAt(0) === '#' || /^(mailto|javascript|tel):/i.test(href)) return null;
      var u; try { u = new URL(href, base + '/'); } catch(e){ return null; }
      var path = u.pathname + u.search;
      if (/\/display\/~|\/users\/|viewuserprofile|\/download\/attachments\//i.test(path)) return null;   // profils, fichiers
      var t = clean(a.textContent) || clean(a.getAttribute('title'));
      var prev = a.previousElementSibling, e = emojiOf(a.querySelector('img[data-emoji-id], img[data-emoji-fallback]'))
        || emojiOf(prev && prev.matches('img[data-emoji-id], img[data-emoji-fallback]') ? prev : null);
      t = clean((e ? e + ' ' : '') + t);
      if (!t) return null;
      var m = path.match(/\/pages\/(\d+)|pageId=(\d+)/);
      return { t: t, u: u.href, id: m ? (m[1] || m[2]) : '', ext: u.host !== bh };
    }
    // Texte sans lettre ni chiffre = émoji seul.
    function onlySymbols(t){ return !/[\p{L}\p{N}]/u.test(t); }
    // Liens d'un bloc, dans l'ordre. Sur le site, l'émoji est souvent un lien À PART collé devant
    // le vrai lien (« 💼 » puis « Documents de cadrage ») : il est rattaché au lien suivant au lieu
    // de faire une tuile vide. Dédoublonnage par PAGE (id) : une liste de commentaires renvoie
    // plusieurs fois vers la même consigne (?focusedCommentId=…).
    function collect(as, max){
      var ls = [], seen = {}, pend = '';
      as.forEach(function(a){
        var l = linkOf(a);
        if (!l) return;
        if (onlySymbols(l.t)) { pend = l.t; return; }
        if (pend && /^[\p{L}\p{N}\[\(«"']/u.test(l.t)) l.t = pend + ' ' + l.t;
        pend = '';
        var k = l.id || l.u.split('#')[0];
        if (seen[k] || ls.length >= max) return;
        seen[k] = 1; ls.push(l);
      });
      return ls;
    }
    var hl = [], secs = [];
    Array.prototype.forEach.call(root.querySelectorAll('div.panel'), function(p){
      if (hl.length >= 12 || !vis(p)) return;
      var h = p.querySelector('.panelHeader'), c = p.querySelector('.panelContent') || p;
      var title = clean(h ? h.textContent : '');
      if (!title) return;
      var ls = collect(Array.prototype.slice.call(c.querySelectorAll('a[href]')), 20);
      var dm = title.match(/^(\d{1,2}\/\d{1,2}(?:\/\d{2,4})?)\s*(.*)$/);
      hl.push({ title: dm ? dm[2] : title, date: dm ? dm[1] : '', text: clean(c.textContent).slice(0, 500), links: ls });
    });
    Array.prototype.forEach.call(root.querySelectorAll('h1, h2, h3, h4'), function(h){
      if (secs.length >= 8 || h.closest('div.panel') || !vis(h)) return;
      var title = clean(h.textContent);
      if (!title) return;
      var all = [], n = h.nextElementSibling;
      while (n && !/^H[1-4]$/.test(n.tagName) && !(n.querySelector && n.querySelector('h1, h2, h3, h4'))) {
        var as = n.matches('a[href]') ? [n] : Array.prototype.slice.call(n.querySelectorAll('a[href]'));
        as.forEach(function(a){ if (!a.closest('div.panel') && vis(a)) all.push(a); });
        n = n.nextElementSibling;
      }
      var ls = collect(all, 24);
      // « Commentaires de l'espace … » (titre du site) -> « Derniers commentaires de l'espace … ».
      // Émoji éventuel en tête conservé ; titre déjà « Derniers … » laissé tel quel.
      if (!/derniers\s+commentaires/i.test(title)) title = title.replace(/^([^\p{L}\p{N}]*)commentaires(\s+de\s+l)/iu, '$1Derniers commentaires$2');
      if (ls.length) secs.push({ title: title, links: ls });
    });
    return { highlights: hl, sections: secs };
  }
  var layout = (function(){
    try {
      var live = document.querySelector('#main-content');
      if (live && P.homeId && location.pathname.indexOf(P.homeId) >= 0) {
        var L = layoutOf(live, true);
        if (L.highlights.length || L.sections.length) { L.src = 'page affichée'; return Promise.resolve(L); }
      }
    } catch(e){ errs.push('mise en page (page): ' + txt(e && e.message)); }
    if (!P.homeId) return Promise.resolve(null);
    return soft('mise en page', get('/rest/api/content/' + P.homeId + '?expand=body.view').then(function(c){
      var html = (c.body && c.body.view && c.body.view.value) || '';
      var d = new DOMParser().parseFromString('<div id="bt-root">' + html + '</div>', 'text/html');
      var L = layoutOf(d.getElementById('bt-root'), false);
      L.src = 'body.view';
      return L;
    }), null);
  })();
  Promise.all([home, rubrics, news, top, fresh, layout]).then(function(r){
    window.__btHome = {state:'OK', id:P.id, homeTitle:txt(r[0] && r[0].title), spaceKey:txt(r[0] && r[0].space && r[0].space.key),
                       rubrics:r[1], news:r[2], top:r[3], fresh:r[4], layout:r[5], errors:errs, ms:Date.now()-t0};
  }).catch(function(e){
    window.__btHome = {state: e && e.auth ? 'AUTH' : 'ERROR', id:P.id, error:txt(e && e.message), ms:Date.now()-t0};
  });
  return 'started';
})(__P__)
'@

# --- JS : sous-pages d'une rubrique (clic sur une tuile) ---
$script:BtKidsJs = @'
(function(P){
  window.__btKids = {state:'PENDING', id:P.id};
  var t0 = Date.now(), base = P.base, out = [];
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function page(start){
    return fetch(base + '/rest/api/content/' + P.pid + '/child/page?start=' + start + '&limit=100&expand=' + encodeURIComponent('children.page,space,history.lastUpdated'),
                 {credentials:'same-origin', headers:{'Accept':'application/json'}}).then(function(r){
      if (r.status === 401) { var e = new Error('HTTP 401'); e.auth = true; throw e; }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    }).then(function(j){
      var res = j.results || [];
      res.forEach(function(c){
        var lu = (c.history && c.history.lastUpdated) || {}, k = 0;
        try { var cp = c.children.page; k = (typeof cp.size === 'number') ? cp.size : (cp.results || []).length; } catch(e){}
        out.push({ id:txt(c.id), type:'page', title:txt(c.title), excerpt:'', url: c._links && c._links.webui ? base + c._links.webui : '',
                   space:txt(c.space && c.space.name), spaceKey:txt(c.space && c.space.key), parent:P.title, modified:txt(lu.when), friendly:'',
                   author:txt(lu.by && lu.by.displayName), labels:[], kids:k });
      });
      if (res.length && j._links && j._links.next && out.length < 500) return page(start + res.length);
      return out;
    });
  }
  page(0).then(function(items){ window.__btKids = {state:'OK', id:P.id, pid:P.pid, items:items, ms:Date.now()-t0}; })
    .catch(function(e){ window.__btKids = {state: e && e.auth ? 'AUTH' : 'ERROR', id:P.id, pid:P.pid, error:txt(e && e.message), ms:Date.now()-t0}; });
  return 'started';
})(__P__)
'@

# --- Données (appelé par la pompe) ---------------------------------------------------
function Step-BtHome {
    param($Ctx)
    $h = $Ctx.Home
    if ($Ctx.Demo) { Step-BtHomeDemo $Ctx; return }
    $live = $Ctx.Ready -and $Ctx.WebView -and $Ctx.WebView.CoreWebView2
    # 1) Aperçu de l'accueil (toutes les 15 min).
    if ($h.Probe.Phase -eq '') {
        $due = $live -and (-not $h.At -or ((Get-Date) - $h.At).TotalMinutes -ge 15)
        if ($due -and -not $Ctx.Search.Active) {
            $h.At = Get-Date
            $h.Id = [guid]::NewGuid().ToString('N')
            $p = @{ id = $h.Id; base = $Ctx.Config.BaseUrl.TrimEnd('/'); space = [string]$Ctx.Config.SpaceKey; homeId = [string]$Ctx.Config.HomePageId
                    days = 30; top = 8; news = 10 } | ConvertTo-Json -Compress
            Start-BtProbe $Ctx $h.Probe ($script:BtHomeJs.Replace('__P__', $p)) 'window.__btHome' 60 $h.Id
        }
    } else {
        $r = Step-BtProbe $Ctx $h.Probe
        if ($r) {
            if ($r.state -eq 'OK') {
                $h.Top = @($r.top | Where-Object { $_ } | ForEach-Object { $_.excerpt = "💬 $($_.n) commentaire(s) ces 30 derniers jours"; $_ })
                $h.Fresh = @($r.fresh | Where-Object { $_ })
                $h.News = @($r.news | Where-Object { $_ })
                $h.Rubrics = @($r.rubrics | Where-Object { $_ })
                if ($r.homeTitle) { $h.HomeTitle = [string]$r.homeTitle }
                if ($r.layout) {
                    $h.Highlights = @($r.layout.highlights | Where-Object { $_ })
                    $h.Sections = @($r.layout.sections | Where-Object { $_ })
                    # Titres des blocs seulement (journal local) : utile pour le calibrage terrain.
                    Write-BtLog ("[ACCUEIL] Mise en page ({0}) : {1} mis en avant ; sections : {2}" -f $r.layout.src, @($h.Highlights).Count,
                        $(if (@($h.Sections).Count) { (@($h.Sections) | ForEach-Object { "$($_.title) ($(@($_.links).Count))" }) -join ' · ' } else { 'aucune' }))
                }
                $h.Error = $null
                $errs = @($r.errors | Where-Object { $_ })
                if ($errs.Count) { Write-BtLog "[ACCUEIL] Parties indisponibles : $($errs -join ' | ')" }
                Write-BtLog ("[ACCUEIL] {0} rubrique(s), {1} news, {2} nouvelle(s) consigne(s), {3} très commentée(s) en {4} ms" -f @($h.Rubrics).Count, @($h.News).Count, @($h.Fresh).Count, @($h.Top).Count, $r.ms)
            } else {
                $h.Error = [string]$r.error
                $h.At = (Get-Date).AddMinutes(-13)              # nouvel essai dans ~2 min
                Write-BtLog "[ACCUEIL] Échec de l'aperçu ($($r.state) $($r.error))."
            }
            if (-not $Ctx.Search.ShownQuery -and -not $Ctx.Browse) { Render-BtResults $Ctx }
        }
    }
    # 2) Sous-pages de la rubrique ouverte.
    if ($h.KidProbe.Phase -eq '') {
        if ($h.KidWant -and $live) {
            $w = $h.KidWant; $h.KidWant = $null
            $h.KidId = [guid]::NewGuid().ToString('N')
            $p = @{ id = $h.KidId; base = $Ctx.Config.BaseUrl.TrimEnd('/'); pid = [string]$w.Id; title = [string]$w.Title } | ConvertTo-Json -Compress
            Start-BtProbe $Ctx $h.KidProbe ($script:BtKidsJs.Replace('__P__', $p)) 'window.__btKids' 45 $h.KidId
        }
        return
    }
    $k = Step-BtProbe $Ctx $h.KidProbe
    if (-not $k) { return }
    $pid_ = [string]$k.pid
    if ($k.state -eq 'OK') {
        $h.Kids[$pid_] = @{ Items = @($k.items | Where-Object { $_ }); Error = $null; At = Get-Date }
        Write-BtLog ("[ACCUEIL] Rubrique {0} : {1} sous-page(s) en {2} ms" -f $pid_, @($k.items).Count, $k.ms)
        # Lien de l'accueil vers une simple consigne (aucune sous-page) : on l'ouvre dans le lecteur.
        $v = Get-BtHomeView $Ctx
        if (-not @($k.items | Where-Object { $_ }).Count -and $v -and $v.Kind -eq 'rubric' -and [string]$v.Id -eq $pid_ -and $v.Item -and [int]$v.Item.kids -lt 0) {
            $h.Nav.RemoveAt($h.Nav.Count - 1)
            Open-BtReader $Ctx $v.Item
        }
    } elseif ($k.state -eq 'AUTH') {
        Write-BtLog "[ACCUEIL] Session expirée pendant le chargement de la rubrique : reconnexion."
        $v = Get-BtHomeView $Ctx
        if ($v -and $v.Kind -eq 'rubric') { $h.KidWant = $v }
        Invoke-BtReconnect $Ctx
        return
    } else {
        if ($pid_) { $h.Kids[$pid_] = @{ Items = @(); Error = [string]$k.error; At = Get-Date } }
        Write-BtLog "[ACCUEIL] Rubrique $pid_ : échec ($($k.state) $($k.error))."
    }
    if (-not $Ctx.Search.ShownQuery -and -not $Ctx.Browse) { Render-BtResults $Ctx }
}

# Mode démo : rubriques et contenus fictifs (test de l'interface hors réseau SNCF).
function Step-BtHomeDemo {
    param($Ctx)
    $h = $Ctx.Home
    if (-not $h.At) {
        $h.At = Get-Date
        $h.Top = @((Get-BtDemoResult 'OPW' 0).items | Where-Object { $_.type -eq 'page' } | Select-Object -First 3 | ForEach-Object { $_.excerpt = "💬 $(12 - 3 * [int]($_.id) % 7) commentaire(s) ces 30 derniers jours"; $_ })
        $h.Fresh = @((Get-BtDemoResult 'consigne' 6).items | Where-Object { $_.type -eq 'page' } | Select-Object -First 3)
        $h.News = @((Get-BtDemoResult 'news' 0).items | Select-Object -First 4 | ForEach-Object { $_.type = 'blogpost'; $_ })
        $i = 0
        $h.Rubrics = @('📢u-DOM', 'Consignes du moment', 'Poste de travail', 'Messagerie & Teams', 'Réseau & VPN', 'Impression', 'Habilitations & comptes',
                       'Téléphonie mobile', 'Applications métiers', 'Sécurité', 'FAQ') | ForEach-Object {
            $i++
            [pscustomobject]@{ id = [string](5000 + $i); type = 'page'; title = $_; excerpt = ''; url = "https://confluence.apps.eul.sncf.fr/pages/viewpage.action?pageId=$(5000 + $i)"
                               space = 'Biblio-TECH'; spaceKey = 'KM'; parent = ''; modified = ''; friendly = ''; author = ''; labels = @(); kids = $(if ($i -eq 10) { 0 } else { 3 + $i }) }
        }
        $h.HomeTitle = 'Bienvenue dans votre Biblio-TECH'
        # Mise en page de l'accueil (calquée sur celle d'un TAM) : sections du profil + mis en avant.
        $u = 'https://confluence.apps.eul.sncf.fr/spaces/KM/pages/'
        $lk = { param($t, $id, $ext = $false) [pscustomobject]@{ t = $t; u = $(if ($ext) { 'https://teams.microsoft.com/l/channel/x' } else { "$u$id/x" }); id = $(if ($ext) { '' } else { [string]$id }); ext = $ext } }
        $h.Sections = @(
            [pscustomobject]@{ title = 'TAM / Gestionnaire en Production'; links = @((& $lk "$([char]::ConvertFromUtf32(0x1F4BB)) Guides techniques et Bonnes pratiques TAMs" 6001), (& $lk "$([char]::ConvertFromUtf32(0x1F4BE)) Sources, manuels et méthodes installation logiciels" 6002),
                (& $lk "$([char]::ConvertFromUtf32(0x1F4E2)) u-DOM" 6003), (& $lk "$([char]::ConvertFromUtf32(0x1F4BC)) Documents de cadrage et Généralités Transverses" 6004), (& $lk 'Teams Assistance au Support' 0 $true), (& $lk 'Engage TAMs' 6006)) },
            [pscustomobject]@{ title = 'Débuter avec Biblio-TECH'; links = @((& $lk 'Je suis offreur' 6101), (& $lk 'astuces de Recherche' 6102), (& $lk "$([char]::ConvertFromUtf32(0x1F4DA)) LEXIQUE métier Assistance Utilisateurs" 6103),
                (& $lk "$([char]::ConvertFromUtf32(0x1F310)) Liens utiles" 6104), (& $lk "$([char]::ConvertFromUtf32(0x1F3ED)) Accès Biblio-Tech / gestion des habilitations" 6105), (& $lk "$([char]0x27A1) Demande de page Biblio-TECH" 6106)) }
        )
        $h.Highlights = @(
            [pscustomobject]@{ title = 'Poste Métier OPW'; date = '20/08'; text = 'Mur d''image uniquement, pas en utilisation pour le déploiement de poste métier'; links = @((& $lk 'OPW métier - Macro CNO' 6201), (& $lk 'OPW métier - CNO Salle de crise' 6202)) },
            [pscustomobject]@{ title = 'Bornes eVote'; date = '06/10'; text = 'Publication des consignes sur le déploiement des Bornes eVotes pour les élections'; links = @((& $lk 'Bornes eVote' 6203)) },
            [pscustomobject]@{ title = 'Messagerie / Offre AAD'; date = '17/09'; text = 'Compte ADM avec Messagerie - Dérogation à l''offreur Messagerie. MAJ de consigne Création de compte ADM et Modification de compte ADM'; links = @((& $lk 'Création de compte ADM' 6204), (& $lk 'Modification de compte ADM' 6205)) },
            [pscustomobject]@{ title = 'DameWare'; date = '24/09'; text = 'Nouvelle consigne DameWare pour les postes virtuels. Évolution consigne DRE postes Windows.'; links = @((& $lk 'Utilisation DAMEWARE (DRE) pour PMAD (postes virtuels)' 6206), (& $lk 'Utilisation DAMEWARE (DRE) pour PMAD (Console lourde)' 6207)) }
        )
        Render-BtResults $Ctx
        # BT_TEST_TILE=<n> : ouvre la n-ième rubrique (test visuel de la « page suivante »).
        if ($env:BT_TEST_TILE) { $r = @($h.Rubrics)[[int]$env:BT_TEST_TILE - 1]; if ($r) { Invoke-BtHomeNav $Ctx @{ Kind = 'rubric'; Id = $r.id; Title = $r.title; Glyph = (Get-BtTileGlyph $r.title); Color = '#4FB3FF'; Item = $r } } }
    }
    if ($h.KidWant) {
        $w = $h.KidWant; $h.KidWant = $null
        $sub = @('Fiches réflexes', 'Procédures détaillées') | ForEach-Object {
            [pscustomobject]@{ id = "$($w.Id)-$_"; type = 'page'; title = $_; excerpt = ''; url = "https://confluence.apps.eul.sncf.fr/pages/viewpage.action?pageId=$($w.Id)9"
                               space = 'Biblio-TECH'; spaceKey = 'KM'; parent = $w.Title; modified = ''; friendly = ''; author = ''; labels = @(); kids = 4 } }
        $leaves = @((Get-BtDemoResult $w.Title 0).items | Where-Object { $_.type -eq 'page' } | ForEach-Object {
            $_.title = $_.title -replace '[\u0001\u0002]', ''; $_.excerpt = ''; $_.parent = $w.Title; $_ | Add-Member -NotePropertyName kids -NotePropertyValue 0 -PassThru })
        $h.Kids[[string]$w.Id] = @{ Items = @($sub) + @($leaves); Error = $null; At = Get-Date }
        Render-BtResults $Ctx
    }
}

# --- Navigation ------------------------------------------------------------------------
function Get-BtHomeView {
    param($Ctx)
    $n = $Ctx.Home.Nav
    if ($n.Count) { return $n[$n.Count - 1] }
    return $null
}

# Cible d'une tuile : Kind = news | fresh | top | recent | rubrics | highlight | rubric | page | ext.
# Rubrique dont le nombre de sous-pages est inconnu (kids = -1, lien de l'accueil) : ouverte,
# puis remplacée par la page elle-même dans le lecteur si elle n'a aucune sous-page.
function Invoke-BtHomeNav {
    param($Ctx, $Target)
    $h = $Ctx.Home
    if ($Target.Kind -eq 'ext') { if ($Target.Item) { Open-BtExternal ([string]$Target.Item.url) }; return }
    if ($Target.Kind -eq 'dashboard') { Show-BtDashboard $Ctx; return }
    if ($Target.Kind -eq 'rubric' -and $Target.Item -and [int]$Target.Item.kids -lt 0) {
        $c = $h.Kids[[string]$Target.Id]
        if ($c -and -not $c.Error -and -not @($c.Items).Count) { Open-BtReader $Ctx $Target.Item; return }
    }
    if ($Target.Kind -eq 'page' -or ($Target.Kind -eq 'rubric' -and $Target.Item -and [int]$Target.Item.kids -eq 0)) {
        if ($Target.Item) { Open-BtReader $Ctx $Target.Item }
        return
    }
    [void]$h.Nav.Add(@{ Kind = $Target.Kind; Id = [string]$Target.Id; Title = [string]$Target.Title; Glyph = $Target.Glyph; Color = $Target.Color; Item = $Target.Item })
    if ($Target.Kind -eq 'rubric') {
        $c = $h.Kids[[string]$Target.Id]
        # Cache de 10 min (une rubrique en échec est redemandée).
        if (-not $c -or $c.Error -or ((Get-Date) - $c.At).TotalMinutes -ge 10) {
            $h.Kids.Remove([string]$Target.Id)
            $h.KidWant = @{ Id = [string]$Target.Id; Title = [string]$Target.Title; Kind = 'rubric' }
        }
    }
    Write-BtLog "[ACCUEIL] Ouverture : $($Target.Kind) « $($Target.Title) »"
    Render-BtResults $Ctx
    Start-BtPageTransition $Ctx 1
}

function Pop-BtHomeNav {
    param($Ctx, [switch]$All)
    $n = $Ctx.Home.Nav
    if (-not $n.Count) { return $false }
    if ($All) { $n.Clear() } else { $n.RemoveAt($n.Count - 1) }
    Render-BtResults $Ctx
    Start-BtPageTransition $Ctx -1
    return $true
}

# --- Animations --------------------------------------------------------------------
function Start-BtAnim {
    param($Target, $Property, [double]$To, [int]$Ms, [string]$Ease = 'out', [object]$From = $null)
    $a = New-Object System.Windows.Media.Animation.DoubleAnimation
    if ($null -ne $From) { $a.From = [double]$From }
    $a.To = $To
    $a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
    if ($Ease -eq 'back') { $e = New-Object System.Windows.Media.Animation.BackEase; $e.Amplitude = 0.4 }
    else { $e = New-Object System.Windows.Media.Animation.CubicEase }
    $e.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $a.EasingFunction = $e
    $Target.BeginAnimation($Property, $a)
    return $a
}

# Entrée de la « page suivante » : glissement latéral + fondu (Dir 1 = avant, -1 = retour).
function Start-BtPageTransition {
    param($Ctx, [int]$Dir = 1)
    $ui = $Ctx.Ui
    if (-not $ui) { return }
    try { $ui.ResultsScroll.ScrollToTop() } catch { }
    $p = $ui.ResultsPanel
    $tt = New-Object System.Windows.Media.TranslateTransform
    $p.RenderTransform = $tt
    [void](Start-BtAnim $tt ([System.Windows.Media.TranslateTransform]::XProperty) 0 260 'out' (36 * $Dir))
    [void](Start-BtAnim $p ([System.Windows.UIElement]::OpacityProperty) 1 220 'out' 0)
}

# --- Tuiles ------------------------------------------------------------------------
$script:BtTilePalette = @('#4FB3FF', '#34D399', '#F59E0B', '#A78BFA', '#F472B6', '#22D3EE', '#FB7185', '#A3E635')

# Pictogramme d'une rubrique d'après son titre (sinon : dossier).
$script:BtTileGlyphs = @(
    @(0xE789, 'news|actu|nouveaut|annonce|info'),
    @(0xE8FD, 'consigne|proc[ée]dure|fiche|mode op'),
    @(0xE7F8, 'poste|pc|ordinateur|windows|portable|mat[ée]riel'),
    @(0xE715, 'mail|messagerie|outlook|courriel'),
    @(0xE8F2, 'teams|visio|collabor|chat'),
    @(0xE701, 'r[ée]seau|vpn|wi-?fi|internet|proxy'),
    @(0xE749, 'impr|scan|copieur'),
    @(0xE717, 't[ée]l[ée]phon|mobile|smartphone|tablette'),
    @(0xE72E, 'habilit|droit|acc[eè]s|compte|mot de passe|identit'),
    @(0xE83D, 's[ée]curit|cyber|virus|phishing'),
    @(0xE71D, 'appli|logiciel|m[ée]tier|outil'),
    @(0xE90F, 'incident|panne|d[ée]pann|r[ée]par|diagnos'),
    @(0xE7BE, 'forma|tuto|guide|apprendre|d[ée]marrer'),
    @(0xE897, 'faq|question|aide'),
    @(0xE716, 'contact|[ée]quipe|annuaire|interlocut')
)

# Émoji en tête d'un titre Confluence (« 📢u-DOM ») : séparé du texte pour servir d'icône
# (sinon WPF le colle au texte). Renvoie @{ Emoji ; Text }.
function Split-BtTitleEmoji {
    param([string]$Title)
    $m = [regex]::Match([string]$Title, '^\s*((?:[\p{So}\p{Sk}\p{Cf}\p{IsMiscellaneousSymbols}\p{IsDingbats}\p{IsVariationSelectors}]|\p{Cs}\p{Cs})+)\s*')
    if ($m.Success -and $m.Length -lt ([string]$Title).Length) { return @{ Emoji = $m.Groups[1].Value.Trim(); Text = ([string]$Title).Substring($m.Length).Trim() } }
    return @{ Emoji = ''; Text = ([string]$Title).Trim() }
}

# Icône d'une tuile / d'un en-tête : l'émoji du titre s'il y en a un, sinon le pictogramme.
function New-BtTitleIcon {
    param([string]$Glyph, [string]$Emoji, [double]$Size, [string]$Color)
    $Color = Get-BtTone $Color
    if ($Emoji) {
        $t = New-BtText -Text $Emoji -Size ($Size - 1) -Color $Color
        $t.FontFamily = New-Object System.Windows.Media.FontFamily 'Segoe UI Emoji'
        return $t
    }
    return (New-BtText -Text $Glyph -Size $Size -Color $Color -Icon)
}

function Get-BtTileGlyph {
    param([string]$Title)
    $t = ([string]$Title).ToLowerInvariant()
    foreach ($g in $script:BtTileGlyphs) { if ($t -match $g[1]) { return [string][char]$g[0] } }
    return [string][char]0xE8B7
}

# Tuile cliquable animée. Tag = cible de navigation (voir Invoke-BtHomeNav).
function New-BtTile {
    param($Ctx, [string]$Title, [string]$Sub, [string]$Glyph, [string]$Color, $Target)
    $Color = Get-BtTone $Color          # couleur vive assombrie en thème clair (lisibilité)
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 168; $tile.Height = 120
    $tile.CornerRadius = New-Object System.Windows.CornerRadius 14
    $tile.Background = Get-BtBrush 'Card'
    $tile.BorderBrush = Get-BtBrush 'Border'
    $tile.BorderThickness = New-BtThickness 1
    $tile.Padding = New-BtThickness 14 12 12 10
    $tile.Margin = New-BtThickness 0 0 10 10
    $tile.Cursor = [System.Windows.Input.Cursors]::Hand
    $sp_ = Split-BtTitleEmoji $Title
    $Title = $sp_.Text
    $tile.ToolTip = $Title
    $tile.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
    $tg = New-Object System.Windows.Media.TransformGroup
    $tg.Children.Add((New-Object System.Windows.Media.ScaleTransform(1, 1)))
    $tg.Children.Add((New-Object System.Windows.Media.TranslateTransform(0, 0)))
    $tile.RenderTransform = $tg

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($h in @('Auto', 'Star', 'Auto')) {
        $rd = New-Object System.Windows.Controls.RowDefinition
        $rd.Height = if ($h -eq 'Star') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        $grid.RowDefinitions.Add($rd)
    }
    $top = New-Object System.Windows.Controls.DockPanel
    $arrow = New-BtText -Text ([string][char]0xE76C) -Size 11 -Color $Color -Icon
    $arrow.Opacity = 0
    $arrow.RenderTransform = New-Object System.Windows.Media.TranslateTransform(-6, 0)
    [System.Windows.Controls.DockPanel]::SetDock($arrow, [System.Windows.Controls.Dock]::Right)
    [void]$top.Children.Add($arrow)
    $ic = New-Object System.Windows.Controls.Border
    $ic.Width = 38; $ic.Height = 38
    $ic.CornerRadius = New-Object System.Windows.CornerRadius 19
    $ic.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $ic.Background = Get-BtBrush ('#2E' + $Color.TrimStart('#'))
    $ic.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
    $ic.RenderTransform = New-Object System.Windows.Media.RotateTransform 0
    $g = New-BtTitleIcon $Glyph $sp_.Emoji 17 $Color
    $g.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $ic.Child = $g
    [void]$top.Children.Add($ic)
    [System.Windows.Controls.Grid]::SetRow($top, 0)
    [void]$grid.Children.Add($top)

    $t = New-BtText -Text $Title -Size 12.5 -Color 'Text' -SemiBold -Wrap
    $t.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
    $t.MaxHeight = 38
    $t.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $t.Margin = New-BtThickness 0 6 0 1
    [System.Windows.Controls.Grid]::SetRow($t, 1)
    [void]$grid.Children.Add($t)
    $st = New-BtText -Text $Sub -Size 10.5 -Color 'Muted'
    $st.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    [System.Windows.Controls.Grid]::SetRow($st, 2)
    [void]$grid.Children.Add($st)
    $tile.Child = $grid

    $tile.Tag = @{ Target = $Target; Color = $Color; Arrow = $arrow; Icon = $ic; Pressed = $false }
    $tile.Add_MouseEnter({ param($s, $e) Set-BtTileHover $s $true })
    $tile.Add_MouseLeave({ param($s, $e) $s.Tag.Pressed = $false; Set-BtTileHover $s $false })
    $tile.Add_MouseLeftButtonDown({ param($s, $e)
        $e.Handled = $true
        $s.Tag.Pressed = $true
        $sc = $s.RenderTransform.Children[0]
        foreach ($pr in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty)) { [void](Start-BtAnim $sc $pr 0.94 90) }
    })
    $tile.Add_MouseLeftButtonUp({ param($s, $e)
        $e.Handled = $true
        if (-not $s.Tag.Pressed) { return }
        $s.Tag.Pressed = $false
        # Ouverture IMMÉDIATE : la page suivante arrive avec sa propre animation (glissement).
        # (Ne pas attendre l'événement Completed d'une animation : branché après BeginAnimation,
        # il ne se déclenche jamais -> en 1.1.11 rien ne s'ouvrait.)
        $sc = $s.RenderTransform.Children[0]
        foreach ($pr in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty)) { [void](Start-BtAnim $sc $pr 1.0 120 'back') }
        try { Invoke-BtHomeNav $script:Ctx $s.Tag.Target } catch { Write-BtLog "[ERREUR UI] Tuile : $($_.Exception.Message)" }
    })
    return $tile
}

# Survol : la tuile grossit, se soulève, se colore, l'icône pivote, la flèche glisse.
function Set-BtTileHover {
    param($Tile, [bool]$On)
    $d = $Tile.Tag
    $sc = $Tile.RenderTransform.Children[0]
    $tr = $Tile.RenderTransform.Children[1]
    $scale = if ($On) { 1.045 } else { 1.0 }
    foreach ($pr in @([System.Windows.Media.ScaleTransform]::ScaleXProperty, [System.Windows.Media.ScaleTransform]::ScaleYProperty)) { [void](Start-BtAnim $sc $pr $scale 180) }
    [void](Start-BtAnim $tr ([System.Windows.Media.TranslateTransform]::YProperty) $(if ($On) { -3 } else { 0 }) 180)
    [void](Start-BtAnim $d.Icon.RenderTransform ([System.Windows.Media.RotateTransform]::AngleProperty) $(if ($On) { -8 } else { 0 }) 220 'back')
    [void](Start-BtAnim $d.Arrow ([System.Windows.UIElement]::OpacityProperty) $(if ($On) { 1 } else { 0 }) 160)
    [void](Start-BtAnim $d.Arrow.RenderTransform ([System.Windows.Media.TranslateTransform]::XProperty) $(if ($On) { 0 } else { -6 }) 180)
    $Tile.BorderBrush = if ($On) { Get-BtBrush $d.Color } else { Get-BtBrush 'Border' }
    $Tile.Background = if ($On) { Get-BtBrush 'CardHover' } else { Get-BtBrush 'Card' }
}

function New-BtSkeletonTile {
    $b = New-Object System.Windows.Controls.Border
    $b.Width = 168; $b.Height = 120
    $b.CornerRadius = New-Object System.Windows.CornerRadius 14
    $b.Background = Get-BtBrush 'Card'
    $b.Margin = New-BtThickness 0 0 10 10
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.45, 1.0, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(750))))
    $anim.AutoReverse = $true
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $b.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
    return $b
}

function Format-BtCount {
    param([int]$N, [string]$One, [string]$Many)
    if ($N -le 0) { return '' }
    if ($N -eq 1) { return "1 $One" }
    return "$N $Many"
}

# Grille de toutes les rubriques (sous-pages de la page d'accueil).
function New-BtRubricTiles {
    param($Ctx)
    $wr = New-Object System.Windows.Controls.WrapPanel
    $i = 0
    foreach ($r in @($Ctx.Home.Rubrics)) {
        $color = $script:BtTilePalette[$i % $script:BtTilePalette.Count]; $i++
        $glyph = Get-BtTileGlyph $r.title
        $subTxt = if ([int]$r.kids -gt 0) { Format-BtCount ([int]$r.kids) 'élément' 'éléments' } else { 'Ouvrir la fiche' }
        [void]$wr.Children.Add((New-BtTile $Ctx ([string]$r.title) $subTxt $glyph $color @{ Kind = 'rubric'; Id = [string]$r.id; Title = [string]$r.title; Glyph = $glyph; Color = $color; Item = $r }))
    }
    return $wr
}

# Tuile d'un lien de la page d'accueil { t; u; id; ext } : page Confluence -> rubrique (ses
# sous-pages, ou la page elle-même si elle n'en a pas) ; lien externe -> navigateur.
function New-BtLinkTile {
    param($Ctx, $Link, [string]$Section, [string]$Color)
    $item = [pscustomobject]@{ id = [string]$Link.id; type = 'page'; title = [string]$Link.t; excerpt = ''; url = [string]$Link.u; space = 'Biblio-TECH'; spaceKey = ''
                               parent = $Section; modified = ''; friendly = ''; author = ''; labels = @(); kids = -1 }
    $kind = if ($Link.ext) { 'ext' } elseif ($Link.id) { 'rubric' } else { 'page' }
    $glyph = if ($Link.ext) { [string][char]0xE8A7 } else { Get-BtTileGlyph ([string]$Link.t) }
    $sub = if ($Link.ext) { 'Lien externe' } else { '' }      # la section est déjà dans l'en-tête
    return (New-BtTile $Ctx ([string]$Link.t) $sub $glyph $Color @{ Kind = $kind; Id = [string]$Link.id; Title = [string]$Link.t; Glyph = $glyph; Color = $Color; Item = $item })
}

# « Les dernières news de Biblio-TECH » (encadrés « Biblio-TECH met en avant » du site) : en
# tête de l'accueil, dans un bandeau à la couleur d'accent, plus visible que les autres sections.
function Add-BtHighlightTiles {
    param($Ctx, $List)
    $hls = @($Ctx.Home.Highlights)
    if (-not $hls.Count) { return }
    $acc = Get-BtTone '#0088CE'
    $band = New-Object System.Windows.Controls.Border
    $band.CornerRadius = New-Object System.Windows.CornerRadius 16
    $band.Background = Get-BtBrush 'AccentSoft'
    $band.BorderBrush = Get-BtBrush $acc
    $band.BorderThickness = New-BtThickness 1.5
    $band.Padding = New-BtThickness 16 12 6 6
    $band.Margin = New-BtThickness 0 12 10 8
    $sp = New-Object System.Windows.Controls.StackPanel

    $hd = New-Object System.Windows.Controls.StackPanel
    $hd.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $hd.Margin = New-BtThickness 0 0 0 10
    $ic = New-Object System.Windows.Controls.Border
    $ic.Width = 34; $ic.Height = 34
    $ic.CornerRadius = New-Object System.Windows.CornerRadius 17
    $ic.Background = Get-BtBrush $acc
    $ic.Margin = New-BtThickness 0 0 10 0
    $g = New-BtText -Text ([string][char]0xE789) -Size 16 -Color '#FFFFFF' -Icon
    $g.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $g.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $ic.Child = $g
    [void]$hd.Children.Add($ic)
    $tx = New-Object System.Windows.Controls.StackPanel
    $tx.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    [void]$tx.Children.Add((New-BtText -Text 'Les dernières news de Biblio-TECH' -Size 16 -Color $acc -Bold))
    [void]$tx.Children.Add((New-BtText -Text 'À la une sur la page d''accueil du site' -Size 11 -Color 'Muted'))
    [void]$hd.Children.Add($tx)
    [void]$sp.Children.Add($hd)

    $wr = New-Object System.Windows.Controls.WrapPanel
    $i = 0
    foreach ($x in $hls) {
        $color = $script:BtTilePalette[($i + 4) % $script:BtTilePalette.Count]
        $glyph = Get-BtTileGlyph ([string]$x.title)
        if ($glyph -eq [string][char]0xE8B7) { $glyph = [string][char]0xE789 }
        $sub = if ($x.date) { "Publié le $($x.date)" } else { 'À la une' }
        $tile = New-BtTile $Ctx ([string]$x.title) $sub $glyph $color @{ Kind = 'highlight'; Id = "hl$i"; Title = [string]$x.title; Glyph = $glyph; Color = $color; Item = $x }
        $tile.Width = 214                                  # tuiles plus larges que les autres
        [void]$wr.Children.Add($tile)
        $i++
    }
    [void]$sp.Children.Add($wr)
    $band.Child = $sp
    [void]$List.Children.Add($band)
}

# --- Rendu -------------------------------------------------------------------------
# Accueil (sans recherche, hors onglet Catégories) : appelé par Render-BtResults.
function Render-BtHome {
    param($Ctx, $List)
    $v = Get-BtHomeView $Ctx
    if ($v) { Render-BtHomeView $Ctx $List $v; return }
    $h = $Ctx.Home
    $s = $Ctx.Search

    # Bandeau de bienvenue.
    $hero = New-Object System.Windows.Controls.StackPanel
    $hero.Margin = New-BtThickness 2 10 0 4
    $title = if ($h.HomeTitle) { $h.HomeTitle } else { 'Bienvenue dans votre Biblio-TECH' }
    [void]$hero.Children.Add((New-BtText -Text $title -Size 18 -Color 'Text' -Bold))
    $sub = New-BtText -Text 'Choisissez une rubrique ou tapez votre question dans la barre de recherche.' -Size 11.5 -Color 'Muted' -Wrap
    $sub.Margin = New-BtThickness 0 3 0 0
    [void]$hero.Children.Add($sub)
    [void]$List.Children.Add($hero)

    # Sections de l'accueil telles que le site les montre à l'utilisateur connecté. Ordre :
    #   1) « Les dernières news de Biblio-TECH » (encadrés mis en avant), en bandeau ;
    #   2) la section du PROFIL (« TAM / Gestionnaire en Production »…) ;
    #   3) les autres sections (« Débuter avec Biblio-TECH »…).
    Add-BtHighlightTiles $Ctx $List
    $secs = @($h.Sections)
    for ($si = 0; $si -lt $secs.Count; $si++) {
        $st = Split-BtTitleEmoji ([string]$secs[$si].title)
        [void]$List.Children.Add((New-BtSectionHeader $st.Text ([string][char]0xE8B7)))
        $color = $script:BtTilePalette[$si % $script:BtTilePalette.Count]
        $wr = New-Object System.Windows.Controls.WrapPanel
        foreach ($l in @($secs[$si].links)) { [void]$wr.Children.Add((New-BtLinkTile $Ctx $l $st.Text $color)) }
        [void]$List.Children.Add($wr)
    }

    # Accès rapides.
    [void]$List.Children.Add((New-BtSectionHeader 'Accès rapides' ([string][char]0xE945)))
    $wp = New-Object System.Windows.Controls.WrapPanel
    $quick = @(
        @{ Kind = 'dashboard'; Title = 'Tableau de bord';   Glyph = [string][char]0xE9D2; Color = '#F97316'; Sub = 'Activité · export Excel' },
        @{ Kind = 'news';  Title = 'Dernières news';        Glyph = [string][char]0xE789; Color = '#F472B6'; Sub = $(if (@($h.News).Count) { Format-BtCount @($h.News).Count 'billet' 'billets' } else { 'Actualités Biblio-TECH' }) },
        @{ Kind = 'fresh';  Title = 'Nouvelles consignes';   Glyph = [string][char]0xE710; Color = '#34D399'; Sub = $(if (@($h.Fresh).Count) { Format-BtCount @($h.Fresh).Count 'nouvelle · 30 j' 'nouvelles · 30 j' } else { '30 derniers jours' }) },
        @{ Kind = 'top';    Title = 'Les plus commentées';   Glyph = [string][char]0xE90A; Color = '#F59E0B'; Sub = '30 derniers jours' },
        @{ Kind = 'recent'; Title = 'Mises à jour récentes'; Glyph = [string][char]0xE823; Color = '#22D3EE'; Sub = 'Consignes modifiées' }
    )
    foreach ($q in $quick) { [void]$wp.Children.Add((New-BtTile $Ctx $q.Title $q.Sub $q.Glyph $q.Color @{ Kind = $q.Kind; Id = $q.Kind; Title = $q.Title; Glyph = $q.Glyph; Color = $q.Color })) }
    $homeItem = [pscustomobject]@{ id = [string]$Ctx.Config.HomePageId; type = 'page'; title = $title; excerpt = ''; url = $Ctx.HomeUrl; space = 'Biblio-TECH'; spaceKey = ''; parent = ''; modified = ''; friendly = ''; author = ''; labels = @() }
    if (@($h.Rubrics).Count -and @($h.Sections).Count) {
        [void]$wp.Children.Add((New-BtTile $Ctx 'Toutes les rubriques' (Format-BtCount @($h.Rubrics).Count 'rubrique' 'rubriques') ([string][char]0xE8B7) '#A78BFA' @{ Kind = 'rubrics'; Id = 'rubrics'; Title = 'Toutes les rubriques'; Glyph = [string][char]0xE8B7; Color = '#A78BFA' }))
    }
    [void]$wp.Children.Add((New-BtTile $Ctx "Page d'accueil" 'Ouvrir dans le lecteur' ([string][char]0xE80F) '#0088CE' @{ Kind = 'page'; Title = "Page d'accueil"; Item = $homeItem }))
    [void]$List.Children.Add($wp)

    # Repli (mise en page de l'accueil illisible) : toutes les rubriques, sous-pages de l'accueil.
    if (@($h.Sections).Count) { }
    elseif (@($h.Rubrics).Count) {
        [void]$List.Children.Add((New-BtSectionHeader 'Rubriques' ([string][char]0xE8B7)))
        [void]$List.Children.Add((New-BtRubricTiles $Ctx))
    } elseif ($h.Error) {
        [void]$List.Children.Add((New-BtSectionHeader 'Rubriques' ([string][char]0xE8B7)))
        [void]$List.Children.Add((New-BtText -Text "Rubriques indisponibles : $($h.Error)" -Size 11.5 -Color 'Muted'))
    } elseif ($h.Probe.Phase -or -not $h.At) {
        [void]$List.Children.Add((New-BtSectionHeader 'Rubriques' ([string][char]0xE8B7)))
        $wr = New-Object System.Windows.Controls.WrapPanel
        for ($k = 0; $k -lt 5; $k++) { [void]$wr.Children.Add((New-BtSkeletonTile)) }
        [void]$List.Children.Add($wr)
    } else {
        [void]$List.Children.Add((New-BtSectionHeader 'Rubriques' ([string][char]0xE8B7)))
        [void]$List.Children.Add((New-BtText -Text 'Aucune rubrique sous la page d''accueil.' -Size 11.5 -Color 'Muted'))
    }

    # Épinglés, puis recherches récentes (compact).
    $pins = @($Ctx.State.Pins)
    if ($pins.Count) {
        [void]$List.Children.Add((New-BtSectionHeader 'Épinglés' ([string][char]0xE840)))
        foreach ($p in $pins) {
            $it = [pscustomobject]@{ id = $p.id; type = $p.type; title = $p.title; excerpt = ''; url = $p.url; space = $p.space; parent = ''; modified = ''; friendly = ''; author = ''; labels = @() }
            [void]$List.Children.Add((New-BtResultCard $Ctx $it))
        }
    }
    $hist = @($Ctx.State.History)
    if ($hist.Count) {
        $hh = New-BtSectionHeader 'Recherches récentes' ([string][char]0xE81C)
        $clr = New-Object System.Windows.Controls.Button
        $clr.Style = $Ctx.Window.Resources['LinkBtn']
        $clr.Content = 'Effacer'
        $clr.Margin = New-BtThickness 8 -3 0 0
        $clr.Add_Click({ Invoke-BtAction $script:Ctx 'clearHistory' })
        [void]$hh.Children.Add($clr)
        [void]$List.Children.Add($hh)
        $wh = New-Object System.Windows.Controls.WrapPanel
        foreach ($hq in ($hist | Select-Object -First 10)) {
            $chip = New-BtChip $hq $false $hq ([string][char]0xE81C)
            $chip.Add_MouseLeftButtonUp({ param($x, $e)
                $script:Ctx.Ui.SearchBox.Text = [string]$x.Tag
                $script:Ctx.Ui.SearchBox.CaretIndex = $script:Ctx.Ui.SearchBox.Text.Length
                $script:Ctx.Search.DebounceAt = $null
                Request-BtSearch $script:Ctx ([string]$x.Tag) 0 'search' -Force
            })
            [void]$wh.Children.Add($chip)
        }
        [void]$List.Children.Add($wh)
    }
}

# « Page suivante » ouverte depuis une tuile.
function Render-BtHomeView {
    param($Ctx, $List, $View)
    $h = $Ctx.Home
    $s = $Ctx.Search

    # En-tête : retour + fil d'Ariane (+ ouvrir la rubrique elle-même).
    $bar = New-Object System.Windows.Controls.DockPanel
    $bar.Margin = New-BtThickness 0 8 0 6
    $back = New-BtIconButton $Ctx ([string][char]0xE72B) 'Retour (Échap)' 'back' 32
    $back.FontSize = 14
    $back.Margin = New-BtThickness 0 0 10 0
    $back.Add_Click({ [void](Pop-BtHomeNav $script:Ctx) })
    [System.Windows.Controls.DockPanel]::SetDock($back, [System.Windows.Controls.Dock]::Left)
    [void]$bar.Children.Add($back)
    if ($View.Kind -eq 'rubric' -and $View.Item) {
        $open = New-Object System.Windows.Controls.Button
        $open.Style = $Ctx.Window.Resources['LinkBtn']
        $open.Content = 'Ouvrir la page de la rubrique'
        $open.Tag = $View.Item
        $open.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $open.Add_Click({ param($x, $e) Open-BtReader $script:Ctx $x.Tag })
        [System.Windows.Controls.DockPanel]::SetDock($open, [System.Windows.Controls.Dock]::Right)
        [void]$bar.Children.Add($open)
    }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $crumb = (@('Accueil') + @($h.Nav | Select-Object -SkipLast 1 | ForEach-Object { (Split-BtTitleEmoji $_.Title).Text })) -join '  ›  '
    $vt = Split-BtTitleEmoji $View.Title
    [void]$sp.Children.Add((New-BtText -Text $crumb -Size 10.5 -Color 'Muted'))
    $tl = New-Object System.Windows.Controls.StackPanel
    $tl.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    if ($View.Glyph -or $vt.Emoji) {
        $gi = New-BtTitleIcon $View.Glyph $vt.Emoji 15 $(if ($View.Color) { $View.Color } else { 'Accent' })
        $gi.Margin = New-BtThickness 0 0 8 0
        [void]$tl.Children.Add($gi)
    }
    [void]$tl.Children.Add((New-BtText -Text $vt.Text -Size 16 -Color 'Text' -Bold))
    [void]$sp.Children.Add($tl)
    [void]$bar.Children.Add($sp)
    [void]$List.Children.Add($bar)

    $empty = 'Rien à afficher pour le moment.'
    if ($View.Kind -eq 'rubrics') { [void]$List.Children.Add((New-BtRubricTiles $Ctx)); return }
    if ($View.Kind -eq 'highlight') {
        $x = $View.Item
        $box = New-Object System.Windows.Controls.Border
        $box.CornerRadius = New-Object System.Windows.CornerRadius 10
        $box.Background = Get-BtBrush 'Card'; $box.BorderBrush = Get-BtBrush 'Border'; $box.BorderThickness = New-BtThickness 1
        $box.Padding = New-BtThickness 14 10 14 10; $box.Margin = New-BtThickness 0 4 0 10
        $sp2 = New-Object System.Windows.Controls.StackPanel
        if ($x.date) { [void]$sp2.Children.Add((New-BtText -Text "Mis en avant le $($x.date)" -Size 11 -Color 'Muted')) }
        $tx = New-BtText -Text ([string]$x.text) -Size 12.5 -Color 'Body' -Wrap
        $tx.Margin = New-BtThickness 0 4 0 0
        [void]$sp2.Children.Add($tx)
        $box.Child = $sp2
        [void]$List.Children.Add($box)
        if (@($x.links).Count) {
            [void]$List.Children.Add((New-BtSectionHeader 'Consignes citées' ([string][char]0xE8A5)))
            $wr = New-Object System.Windows.Controls.WrapPanel
            foreach ($l in @($x.links)) { [void]$wr.Children.Add((New-BtLinkTile $Ctx $l ([string]$View.Title) ([string]$View.Color))) }
            [void]$List.Children.Add($wr)
        }
        return
    }
    switch ($View.Kind) {
        'news'   { $items = @($h.News); $empty = 'Aucune news publiée récemment.' }
        'fresh'  { $items = @($h.Fresh); $empty = 'Aucune nouvelle consigne sur les 30 derniers jours.' }
        'top'    { $items = @($h.Top); $empty = 'Aucune consigne commentée sur les 30 derniers jours.' }
        'recent' {
            if ($s.RecentError) {
                [void]$List.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE783) 'Chargement impossible' $s.RecentError 'Réessayer' 'retry' 'Error'))
                return
            }
            $items = @($s.Recent)
            if (-not $items.Count -and ($s.Pending -or $s.Active)) { for ($i = 0; $i -lt 3; $i++) { [void]$List.Children.Add((New-BtSkeletonCard)) }; return }
        }
        'rubric' {
            $c = $h.Kids[[string]$View.Id]
            if (-not $c) { for ($i = 0; $i -lt 4; $i++) { [void]$List.Children.Add((New-BtSkeletonCard)) }; return }
            if ($c.Error) {
                [void]$List.Children.Add((New-BtMessageCard $Ctx ([string][char]0xE783) 'Rubrique indisponible' "Confluence n'a pas répondu : $($c.Error)" '' '' 'Error'))
                return
            }
            $subs = @($c.Items | Where-Object { [int]$_.kids -gt 0 })
            $items = @($c.Items | Where-Object { [int]$_.kids -le 0 })
            if ($subs.Count) {
                [void]$List.Children.Add((New-BtSectionHeader 'Sous-rubriques' ([string][char]0xE8B7)))
                $wr = New-Object System.Windows.Controls.WrapPanel
                $i = 0
                foreach ($r in $subs) {
                    $color = if ($View.Color) { $View.Color } else { $script:BtTilePalette[$i % $script:BtTilePalette.Count] }; $i++
                    $glyph = Get-BtTileGlyph $r.title
                    [void]$wr.Children.Add((New-BtTile $Ctx ([string]$r.title) (Format-BtCount ([int]$r.kids) 'élément' 'éléments') $glyph $color @{ Kind = 'rubric'; Id = [string]$r.id; Title = [string]$r.title; Glyph = $glyph; Color = $color; Item = $r }))
                }
                [void]$List.Children.Add($wr)
            }
            if ($items.Count) { [void]$List.Children.Add((New-BtSectionHeader ('Consignes · {0}' -f $items.Count) ([string][char]0xE8A5))) }
            elseif (-not $subs.Count) { $empty = 'Cette rubrique ne contient pas encore de consigne.' }
            else { return }
        }
    }
    if (-not $items.Count) { [void]$List.Children.Add((New-BtText -Text $empty -Size 11.5 -Color 'Muted')); return }
    # Affichage par lots de 25 cartes : créer des centaines de cartes d'un coup fige la fenêtre.
    if (-not $View.Show) { $View.Show = 25 }
    foreach ($it in ($items | Select-Object -First $View.Show)) { [void]$List.Children.Add((New-BtResultCard $Ctx $it)) }
    if ($items.Count -gt $View.Show) {
        $b = New-Object System.Windows.Controls.Button
        $b.Style = $Ctx.Window.Resources['PrimaryBtn']
        $b.Content = 'Afficher plus ({0} restantes)' -f ($items.Count - $View.Show)
        $b.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $b.Margin = New-BtThickness 0 4 0 10
        $b.Tag = $View
        $b.Add_Click({ param($x, $e) $x.Tag.Show += 25; Render-BtResults $script:Ctx })
        [void]$List.Children.Add($b)
    }
}
