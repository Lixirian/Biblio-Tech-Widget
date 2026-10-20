# ============================================================================
#  Recherche Confluence : construction de la requête CQL + scripts JS exécutés
#  DANS la page Confluence (same-origin, session SSO).
#
#  Cascade de stratégies (mode 'auto'), la première qui répond gagne :
#    1. /rest/api/search          -> résultats + extraits surlignés (@@@hl@@@)
#    2. /rest/api/content/search  -> résultats sans extrait (repli)
#    3. /dosearchsite.action      -> SCRAPING du HTML de la page de recherche
#  Les marqueurs de surlignage sont normalisés en \u0001 (début) / \u0002 (fin).
#  Format d'un résultat : { id, type, title, excerpt, url, space, spaceKey,
#  parent, modified, friendly, author, labels[] }.
# ============================================================================

# Échappe une valeur pour l'insérer entre guillemets dans une requête CQL.
function ConvertTo-BtCqlString {
    param([string]$Value)
    return (([string]$Value) -replace '\\', '\\' -replace '"', '\"')
}

# Requête CQL complète selon les filtres mémorisés (State.Scope/Type/Sort) et
# l'analyse de la saisie (Resolve-BtQuery, lib\BtAssist.ps1).
# -Recent : pages/blogs (de l'espace s'il est configuré) triés par date de modification (accueil).
# Sans option : TOUTES les notions dans le texte (liste principale).
# -Relaxed : au moins une des notions (relance automatique si 0 résultat en strict).
# -TitleOnly : toutes les notions dans le TITRE (bloc prioritaire en tête, tri pertinence) ;
#   renvoie '' quand ce bloc n'a pas de sens (tri par date, relance élargie, pas de notion).
function Get-BtCql {
    param($Ctx, $Analysis, [switch]$Recent, [switch]$Relaxed, [switch]$TitleOnly)
    if ($TitleOnly) {
        if ($Recent -or $Relaxed -or -not $Analysis -or $Ctx.State.Sort -eq 'recent' -or $Analysis.Intent -eq 'news') { return '' }
        $tc = Format-BtKeywordClause $Analysis -Field title
        if (-not $tc) { return '' }
    }
    $st = $Ctx.State
    $parts = New-Object System.Collections.Generic.List[string]
    if ($Ctx.Config.SpaceKey -and ($Recent -or $st.Scope -ne 'all')) {
        $parts.Add(('space = "{0}"' -f (ConvertTo-BtCqlString $Ctx.Config.SpaceKey)))
    }
    if ($Recent) { $types = @('page') }
    else {
        $types = switch ($st.Type) {
            'page'       { @('page') }
            'blogpost'   { @('blogpost') }
            'attachment' { @('attachment') }
            default      { @($Ctx.Config.ContentTypes) }
        }
    }
    $parts.Add('type in (' + ($types -join ', ') + ')')
    if (-not $Recent -and $Analysis) {
        $kc = if ($TitleOnly) { $tc } else { Format-BtKeywordClause $Analysis -Relaxed:$Relaxed }
        if ($kc) { $parts.Add('(' + $kc + ')') }
        if ($Analysis.Since) { $parts.Add(('lastmodified >= now("{0}")' -f $Analysis.Since)) }
    }
    $cql = $parts -join ' AND '
    # « Quoi de neuf ? » sans autre notion : tri par date, même en mode pertinence.
    $byDate = $Recent -or $st.Sort -eq 'recent' -or ($Analysis -and $Analysis.Intent -eq 'news')
    if ($byDate) { $cql += ' ORDER BY lastmodified DESC' }
    return $cql
}

# --- JS : recherche ------------------------------------------------------------
$script:BtSearchJs = @'
(function(P){
  window.__btSearch = {state:'PENDING', id:P.id};
  var t0 = Date.now(), errs = [], base = P.base;
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function msg(e){ return txt(e && (e.message || e)); }
  var ta = document.createElement('textarea');
  function clean(s){
    s = txt(s).replace(/@@@hl@@@/g,'\u0001').replace(/@@@endhl@@@/g,'\u0002');
    s = s.replace(/<[^>]*>/g,' ');
    ta.innerHTML = s;
    return ta.value.replace(/\s+/g,' ').trim();
  }
  function abs(b, u){ u = txt(u); if(!u) return ''; if(/^https?:\/\//i.test(u)) return u; return b + (u.charAt(0)==='/' ? '' : '/') + u; }
  function req(url){
    var ctl = (typeof AbortController !== 'undefined') ? new AbortController() : null;
    var tm = ctl ? setTimeout(function(){ try{ ctl.abort(); }catch(e){} }, P.timeoutMs) : null;
    return fetch(url, {credentials:'same-origin', headers:{'Accept':'application/json, text/html;q=0.8'}, signal: ctl ? ctl.signal : undefined})
      .then(function(r){ if(tm) clearTimeout(tm); return r; }, function(e){ if(tm) clearTimeout(tm); throw e; });
  }
  function authErr(m){ var e = new Error(m); e.auth = true; return e; }
  function checkAuth(r){
    if (r.status === 401) throw authErr('HTTP 401 (session expirée)');
    if (r.redirected && /login|saml|sso|openam|idp|oauth/i.test(r.url)) throw authErr('redirigé vers la connexion');
  }
  function asJson(r){
    checkAuth(r);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    var ct = txt(r.headers.get('content-type')).toLowerCase();
    if (ct.indexOf('json') < 0) throw new Error('réponse non JSON (' + ct + ')');
    return r.json();
  }
  function done(o){ o.state='OK'; o.id=P.id; o.ms=Date.now()-t0; o.errors=errs; window.__btSearch=o; }
  function fail(state, m){ window.__btSearch = {state:state, id:P.id, error:m, errors:errs, ms:Date.now()-t0}; }
  function qsOf(cql, start, limit){ return 'cql=' + encodeURIComponent(cql) + '&start=' + start + '&limit=' + limit; }

  // Chaque stratégie renvoie {items, total, more, via} pour la requête (cql, start, limit) donnée.
  function viaSearch(cql, start, limit){
    return req(base + '/rest/api/search?' + qsOf(cql, start, limit) + '&excerpt=highlight&expand=' + encodeURIComponent('content.space,content.history.lastUpdated,content.metadata.labels'))
      .then(asJson).then(function(j){
        var b = (j._links && j._links.base) || base;
        var items = (j.results || []).map(function(r){
          var c = r.content || {}, sp = c.space || {}, lu = (c.history && c.history.lastUpdated) || {}, labels = [];
          try { (c.metadata.labels.results || []).forEach(function(l){ labels.push(l.name); }); } catch(e){}
          return { id:txt(c.id), type:txt(c.type || r.entityType), title:clean(r.title || c.title), excerpt:clean(r.excerpt),
            url:abs(b, r.url || (c._links && c._links.webui)),
            space:txt(sp.name || (r.resultGlobalContainer && r.resultGlobalContainer.title)), spaceKey:txt(sp.key),
            parent:txt(r.resultParentContainer && r.resultParentContainer.title),
            modified:txt(r.lastModified || lu.when), friendly:txt(r.friendlyLastModified),
            author:txt(lu.by && lu.by.displayName), labels:labels };
        });
        var total = (typeof j.totalSize === 'number') ? j.totalSize : items.length;
        return {items:items, total:total, more:(start + items.length) < total, via:'rest-search'};
      });
  }

  function viaContent(cql, start, limit){
    return req(base + '/rest/api/content/search?' + qsOf(cql, start, limit) + '&expand=' + encodeURIComponent('space,history.lastUpdated,metadata.labels,container'))
      .then(asJson).then(function(j){
        var b = (j._links && j._links.base) || base;
        var items = (j.results || []).map(function(c){
          var sp = c.space || {}, lu = (c.history && c.history.lastUpdated) || {}, labels = [];
          try { (c.metadata.labels.results || []).forEach(function(l){ labels.push(l.name); }); } catch(e){}
          return { id:txt(c.id), type:txt(c.type), title:clean(c.title), excerpt:'', url:abs(b, c._links && c._links.webui),
            space:txt(sp.name), spaceKey:txt(sp.key), parent:txt(c.container && c.container.title),
            modified:txt(lu.when), friendly:'', author:txt(lu.by && lu.by.displayName), labels:labels };
        });
        var more = !!(j._links && j._links.next);
        var total = (typeof j.totalSize === 'number') ? j.totalSize : (start + items.length + (more ? 1 : 0));
        return {items:items, total:total, more:more, via:'rest-content'};
      });
  }

  function viaDom(){
    var url = base + '/dosearchsite.action?cql=' + encodeURIComponent(P.cql) + '&queryString=' + encodeURIComponent(P.q) + '&startIndex=' + P.start;
    return req(url).then(function(r){ checkAuth(r); if(!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .then(function(html){
        var doc = new DOMParser().parseFromString(html, 'text/html');
        if (doc.querySelector('#loginform, form[name="loginform"], #os_username')) throw authErr('page de connexion');
        var nodes = doc.querySelectorAll('ol.search-results > li, li.search-result, .search-results-container li');
        var items = [];
        Array.prototype.forEach.call(nodes, function(li){
          var a = li.querySelector('a.search-result-link, .search-result-title a, h3 a, a[href]');
          if (!a) return;
          var href = txt(a.getAttribute('href'));
          Array.prototype.forEach.call(li.querySelectorAll('strong, b, mark, .search-highlight, .highlight'), function(h){ h.textContent = '\u0001' + h.textContent + '\u0002'; });
          var ex = li.querySelector('.highlights, .search-result-summary, .search-result-excerpt, p');
          var meta = li.querySelector('.search-result-meta, .search-result-date, .date');
          var spc = li.querySelector('.search-result-space, .container, .search-result-container');
          var m = href.match(/pageId=(\d+)/);
          var cls = txt(li.className) + ' ' + href;
          items.push({ id: m ? m[1] : href, type: /attachment|download\/attachments/i.test(cls) ? 'attachment' : (/blog/i.test(cls) ? 'blogpost' : 'page'),
            title: clean(a.textContent), excerpt: ex ? clean(ex.textContent) : '', url: abs(base, href),
            space: spc ? clean(spc.textContent).replace(/[\u0001\u0002]/g,'') : '', spaceKey:'', parent:'',
            modified:'', friendly: meta ? clean(meta.textContent).replace(/[\u0001\u0002]/g,'') : '', author:'', labels:[] });
        });
        if (!items.length && !doc.querySelector('.search-results, .search-results-container, #search-results-body, .search-results-wrapper')) throw new Error('structure de page inconnue');
        var total = items.length;
        var cnt = doc.querySelector('.search-results-count, .search-result-count, .result-count');
        if (cnt) { var n = parseInt(txt(cnt.textContent).replace(/\D/g,''), 10); if (!isNaN(n)) total = n; }
        return {items:items, total:total, more:(P.start + items.length) < total, via:'dom'};
      });
  }

  var main = (P.strategy === 'dom') ? viaDom() :
    viaSearch(P.cql, P.start, P.limit)
      .catch(function(e){ if (e && e.auth) throw e; errs.push('rest-search: ' + msg(e)); return viaContent(P.cql, P.start, P.limit); })
      .catch(function(e){ if (e && e.auth) throw e; errs.push('rest-content: ' + msg(e)); return viaDom(); });
  // Blocs PRIORITAIRES (1re page) placés en tête, dans l'ordre donné (aujourd'hui : toutes les
  // notions dans le TITRE). Facultatifs : un bloc en échec est simplement ignoré.
  var prio = (P.start === 0 && P.strategy !== 'dom') ? (P.prio || []) : [];
  var blocks = prio.map(function(c){
    return viaSearch(c, 0, P.prioLimit)
      .catch(function(){ return viaContent(c, 0, P.prioLimit); })
      .catch(function(e){ errs.push('priorité: ' + msg(e)); return null; });
  });
  var chain = Promise.all([Promise.all(blocks), main]).then(function(a){
    var bl = a[0], m = a[1], seen = {}, items = [], ids = [], counts = [];
    bl.forEach(function(t, k){
      counts.push(t ? t.items.length : 0);
      if (t) t.items.forEach(function(it){ if (it.id && !seen[it.id]) { seen[it.id] = 1; if (k === 0) it.titleHit = true; items.push(it); ids.push(it.id); } });
    });
    m.items.forEach(function(it){ if (!it.id || !seen[it.id]) { if (it.id) seen[it.id] = 1; items.push(it); } });
    m.items = items;
    m.titleIds = ids;
    m.prioCounts = counts;
    done(m);
  });
  chain.catch(function(e){
    if (e && e.auth) { fail('AUTH', msg(e)); return; }
    errs.push('dom: ' + msg(e));
    fail('ERROR', errs.join(' | '));
  });
  return 'started';
})(__P__)
'@

function Get-BtSearchKickJS {
    param($Ctx, [string]$Id, [string]$Cql, [string]$Query, [int]$Start, [string[]]$Prio = @())
    $p = @{
        id        = $Id
        base      = $Ctx.Config.BaseUrl.TrimEnd('/')
        cql       = $Cql
        prio      = @($Prio | Where-Object { $_ })
        prioLimit = 100
        q         = $Query
        start     = $Start
        limit     = [int]$Ctx.Config.PageSize
        timeoutMs = [int]$Ctx.Config.FetchTimeoutSec * 1000
        strategy  = [string]$Ctx.Config.SearchStrategy
    } | ConvertTo-Json -Compress
    return $script:BtSearchJs.Replace('__P__', $p)
}

# --- JS : identité + espace (validation de la session) -------------------------
# 1) méta-balises de la page (ajs-remote-user) ; 2) /rest/api/user/current.
# Un utilisateur 'anonymous' = pas connecté -> AUTH.
$script:BtInfoJs = @'
(function(P){
  window.__btInfo = {state:'PENDING'};
  function txt(v){ return (v===null||v===undefined) ? '' : String(v); }
  function meta(n){ var m = document.querySelector('meta[name="' + n + '"]'); return m ? txt(m.getAttribute('content')) : ''; }
  function j(u){
    return fetch(P.base + u, {credentials:'same-origin', headers:{'Accept':'application/json'}})
      .then(function(r){
        if (r.status === 401) return {__auth:true};
        var ct = txt(r.headers.get('content-type'));
        if (!r.ok || ct.indexOf('json') < 0) return {__err:'HTTP ' + r.status};
        return r.json();
      }).catch(function(e){ return {__err:txt(e && e.message)}; });
  }
  Promise.all([j('/rest/api/user/current'), (P.space ? j('/rest/api/space/' + encodeURIComponent(P.space)) : Promise.resolve({}))]).then(function(a){
    var u = a[0] || {}, s = a[1] || {};
    var mUser = meta('ajs-remote-user'), mName = meta('ajs-current-user-fullname');
    var logged;
    if (u.__auth) logged = false;
    else if (u.__err) logged = !!mUser;
    else logged = !(u.type === 'anonymous' || (!u.username && !u.userKey && !u.displayName));
    window.__btInfo = { state: logged ? 'OK' : 'AUTH', user: txt(u.username || mUser), fullName: txt(u.displayName || mName),
      space: txt(s.name), spaceKey: txt(s.key || P.space), error: txt(u.__err || s.__err) };
  });
  return 'started';
})(__P__)
'@

function Get-BtInfoKickJS {
    param($Ctx)
    $p = @{ base = $Ctx.Config.BaseUrl.TrimEnd('/'); space = $Ctx.Config.SpaceKey } | ConvertTo-Json -Compress
    return $script:BtInfoJs.Replace('__P__', $p)
}

# --- JS : mode lecture du lecteur intégré (masque le chrome Confluence) ---------
function Get-BtReaderCssJS {
    param([bool]$On)
    $flag = if ($On) { 'true' } else { 'false' }
    return @'
(function(on){
  var id = 'bt-reader-css', el = document.getElementById(id);
  if (!on) { if (el) el.parentNode.removeChild(el); return 'off'; }
  if (el) return 'on';
  el = document.createElement('style'); el.id = id;
  // Lien vers un commentaire (focusedCommentId) : la zone des commentaires reste visible.
  var cm = /[?&]focusedCommentId=/.test(location.search) ? '' : '#comments-section,';
  el.textContent = '#header,#navigation,.ia-fixed-sidebar,.ia-splitter-left,#footer,#app-switcher,.aui-header,'
    + '#likes-and-labels-container,' + cm + '.page-metadata-banner,#editor-preload-container{display:none!important}'
    + '#main,.ia-splitter #main{margin:0 auto!important;padding:28px 48px!important;max-width:1100px;border:0!important}'
    + '#content,.ia-content-container{margin:0!important}body{background:#fff!important}';
  (document.head || document.documentElement).appendChild(el);
  return 'on';
})(__ON__)
'@.Replace('__ON__', $flag)
}

# --- Résultats de démonstration (BT_DEMO=1 : test de l'interface hors réseau SNCF) ---
function Get-BtDemoResult {
    param([string]$Query, [int]$Start, [switch]$Recent)
    $h = [char]1; $e = [char]2
    $q = if ($Query) { $Query } else { 'procédure' }
    $titles = @("Procédure $h$q$e - poste de travail", "FAQ : $h$q$e et VPN", "Guide de dépannage $h$q$e",
        "Note technique - $h$q$e Office 365", "Modèle de compte rendu d'incident", "Inventaire des applications métiers")
    $types = @('page', 'page', 'page', 'page', 'page', 'page')
    $items = for ($i = 0; $i -lt 6; $i++) {
        [pscustomobject]@{
            id = [string](1000 + $Start + $i); type = $types[$i]; title = $titles[$i]
            excerpt = "Cette fiche décrit la marche à suivre lorsque $h$q$e est signalé par l'utilisateur : vérifications préalables, résolution et escalade vers le niveau 2."
            url = "https://confluence.apps.eul.sncf.fr/pages/viewpage.action?pageId=$(1000 + $Start + $i)"
            space = 'Support poste de travail'; spaceKey = 'SPT'; parent = 'Fiches réflexes'
            modified = (Get-Date).AddDays(-$i * 3).ToString('o'); friendly = ''; author = 'Équipe Biblio-Tech'
            labels = @('fiche-reflexe', 'niveau1')
        }
    }
    return [pscustomobject]@{ state = 'OK'; via = 'démo'; ms = 120; items = @($items); total = 14; more = ($Start + 6) -lt 14 }
}
