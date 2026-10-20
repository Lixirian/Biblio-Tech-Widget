# ============================================================================
#  Assistant de recherche en langage courant (LOCAL : aucune IA externe, aucune
#  donnée envoyée hors de Confluence).
#
#  « mon vpn se déconnecte sans arrêt depuis cette semaine, que faire ? »
#    -> intention : résoudre un incident
#    -> notions    : vpn | déconnexion (déconnecte, coupure, connexion perdue…)
#    -> période    : 7 derniers jours
#    -> CQL        : (text ~ "vpn") AND (text ~ "déconnecte" OR text ~ "coupure"…)
#  Si la version stricte (toutes les notions) ne trouve rien, la recherche est
#  relancée automatiquement en version élargie (au moins une notion).
# ============================================================================

# Mots vides (articles, pronoms, tournures de question) : ignorés dans la recherche.
$script:BtStopWords = @{}
@'
a à au aux avec ce ces cet cette ceci cela ça c d de des du dans en et est sont être ai as avons avez ont été
il ils elle elles je j tu t nous vous on le la les l lui leur leurs me m mon ma mes ton ta tes son sa ses notre nos votre vos
ne n pas plus moins ni ou où que qu quoi qui quel quelle quels quelles quand comment pourquoi combien dont
se s si sur sous par pour sans chez vers entre très trop peu bien aussi encore déjà toujours jamais
un une y faire fais fait faut dois doit devons devez peux peut pouvons pouvez puis veux veut voudrais aimerais
besoin aide aider svp merci bonjour stp hello là ici alors donc car mais comme tout tous toute toutes autre autres
avoir eu fois depuis puisque lorsque lors chaque même cas quoi rien
moi toi donne donnez donner montre montrez montrer affiche affichez afficher sors sortez sortir sort liste listez lister
trouve trouvez retrouve retrouver envoie envoyer indique indiquer dis dites voir obtenir connaître connaitre souhaite souhaiterais
concerne concernent concernant concernée concernées propos sujet relatif relative relatifs relatives rapport traite traitent parle parlent
info infos information informations renseignement renseignements documentation doc docs élément éléments existe existent existant est-ce documenté documentée documentés documentées
'@ -split '\s+' | Where-Object { $_ } | ForEach-Object { $script:BtStopWords[$_] = $true }

# Tournures sans valeur de recherche (retirées AVANT le découpage en mots).
$script:BtNoise = @(
    'sans arr[eê]t', 'tout le temps', 'de temps en temps', 'que faire', 'quoi faire', 'que dois-je faire',
    'mis(es)? à jour', 'mise à jour r[ée]cente', 'nouvelles? fiches?', 'quelles? fiches?', 'quelles? pages?',
    'une fiche', 'la fiche', 'une proc[ée]dure', 'la proc[ée]dure', 'trouver', 'cherche[rz]?', 'savoir',
    "j'ai", "je n'arrive pas [àa]", "n'arrive pas [àa]", 'il y a', 'est-ce que', 'est ce que',
    # Formules de demande (« donne-moi tout ce qui concerne les bornes evote ») : sans elles,
    # chaque mot devenait une notion OBLIGATOIRE et la recherche ne trouvait presque rien.
    '(donne|donnez|montre|montrez|affiche|affichez|sors|sortez|trouve|trouvez|liste|listez|envoie|envoyez|indique|indiquez|dis|dites)[- ]moi',
    'je (veux|voudrais|souhaite|souhaiterais|cherche|recherche|aimerais) (avoir|voir|conna[iî]tre|obtenir|trouver)?',
    "(tout|toutes?) (ce|celles?|ceux) (qui|qu'il y a|que)( (concerne(nt)?|touche(nt)?|traite(nt)?|parle(nt)?|existe(nt)?|a trait))?",
    '(toutes? )?les (infos?|informations?|fiches?|pages?|documents?|docs?|proc[ée]dures?|consignes?|articles?)( (sur|concernant|relatives?|li[ée]es|disponibles?))?',
    '[àa] propos (de|du|des|d)', 'au sujet (de|du|des|d)', 'en (rapport|lien) avec', 'relati(f|ve|fs|ves) (à|a|au|aux)',
    "qu'est[- ]ce qu'il y a", 'y a[- ]t[- ]il', 'il existe'
)

# Synonymes métier (support poste de travail). Clé = forme saisie ; valeur = variantes
# cherchées EN PLUS. Les expressions de plusieurs mots sont reconnues telles quelles.
$script:BtSynonyms = [ordered]@{
    'mot de passe'   = @('mot de passe', 'mdp', 'password', 'réinitialisation')
    'mdp'            = @('mot de passe', 'réinitialisation')
    'compte bloqué'  = @('compte verrouillé', 'déverrouillage', 'déblocage')
    'bloqué'         = @('verrouillé', 'bloquage', 'déblocage')
    'pc'             = @('poste', 'ordinateur')
    'ordinateur'     = @('poste', 'pc')
    'portable'       = @('ordinateur portable', 'laptop')
    'rame'           = @('lenteur', 'lent', 'performances')
    'lent'           = @('lenteur', 'performances')
    'internet'       = @('réseau', 'connexion', 'proxy', 'navigation')
    'wifi'           = @('wi-fi', 'sans fil', 'réseau')
    'déconnecte'     = @('déconnexion', 'coupure', 'connexion perdue')
    'coupe'          = @('coupure', 'déconnexion')
    'imprimer'       = @('impression', 'imprimante')
    'imprimante'     = @('impression', 'imprimer')
    'mail'           = @('messagerie', 'outlook', 'courriel')
    'mails'          = @('messagerie', 'outlook', 'courriel')
    'email'          = @('messagerie', 'outlook', 'courriel')
    'écran'          = @('moniteur', 'affichage')
    'audio'          = @('son', 'haut-parleur', 'casque')
    'micro'          = @('microphone', 'audio')
    'nouvel arrivant'= @('arrivée', 'onboarding', 'nouvel arrivant')
    'arrivant'       = @('arrivée', 'onboarding')
    'départ'         = @('sortie', 'restitution')
    'installer'      = @('installation', 'déploiement')
    'installation'   = @('installer', 'déploiement')
    'erreur'         = @('message d''erreur', 'code erreur')
    'plante'         = @('plantage', 'crash', 'ne répond pas')
    'marche pas'     = @('ne fonctionne pas', 'dysfonctionnement', 'panne')
    'fonctionne pas' = @('dysfonctionnement', 'panne')
    'teams'          = @('visio', 'visioconférence')
    'visio'          = @('teams', 'visioconférence')
    'badge'          = @('carte', 'accès')
    'téléphone'      = @('mobile', 'smartphone')
    'droits'         = @('habilitation', 'accès', 'autorisation')
    'accès'          = @('habilitation', 'droits')
}

# Intentions reconnues (la première qui correspond l'emporte).
$script:BtIntents = @(
    @{ Key = 'news';      Label = 'Voir les nouveautés';        Rx = '\b(nouveaut|nouvelles? fiches?|mis(es)? à jour|derni[eè]res?|r[ée]cemment)' }
    @{ Key = 'incident';  Label = 'Résoudre un incident';       Rx = '\b(erreur|bug|plant|crash|bloqu|marche pas|fonctionne pas|arrive pas|n.arrive|ne r[ée]pond|panne|impossible|probl[eè]me|coup|d[ée]connect|rame|lent)' }
    @{ Key = 'procedure'; Label = 'Suivre une procédure';       Rx = '\b(comment|proc[ée]dure|installer|configurer|param[ée]trer|cr[ée]er|demander|ajouter|activer|d[ée]sactiver|pr[ée]parer|[ée]tapes?)' }
    @{ Key = 'definition';Label = 'Comprendre une notion';      Rx = '\b(c.est quoi|qu.est.ce|d[ée]finition|diff[ée]rence|signifie)' }
)

# Période (« cette semaine », « aujourd'hui »…) -> fonction CQL now().
$script:BtPeriods = @(
    @{ Rx = "aujourd.hui|ce jour";            Since = '-1d';  Label = "aujourd'hui" }
    @{ Rx = 'cette semaine|7 derniers jours|semaine derni'; Since = '-7d';  Label = '7 derniers jours' }
    @{ Rx = 'ce mois|30 derniers jours|mois derni';         Since = '-30d'; Label = '30 derniers jours' }
)

# Variante « racine* » pour les mots longs (déconnexions -> déconnex*).
function Get-BtStem {
    param([string]$Word)
    $w = $Word.TrimEnd('s', 'x')
    if ($w.Length -lt 8) { return $null }
    return $w.Substring(0, [Math]::Max(5, $w.Length - 3)) + '*'
}

# Analyse la saisie. Renvoie l'intention, les notions (groupes de variantes),
# les expressions exactes, la période et un libellé « ce que j'ai compris ».
function Resolve-BtQuery {
    param([string]$Query)
    $raw = ([string]$Query).Trim()
    $norm = $raw.ToLowerInvariant() -replace "[’`]", "'"
    $a = [ordered]@{ Raw = $raw; Natural = $false; Intent = ''; IntentLabel = ''; Groups = @(); Phrases = @(); Since = ''; SinceLabel = ''; Keywords = '' }

    # Expressions exactes entre guillemets : conservées telles quelles.
    foreach ($m in [regex]::Matches($norm, '"([^"]{2,})"')) { $a.Phrases += $m.Groups[1].Value.Trim() }
    $norm = [regex]::Replace($norm, '"[^"]*"', ' ')

    foreach ($p in $script:BtPeriods) { if ($norm -match $p.Rx) { $a.Since = $p.Since; $a.SinceLabel = $p.Label; $norm = [regex]::Replace($norm, $p.Rx, ' '); break } }
    foreach ($i in $script:BtIntents) { if ($norm -match $i.Rx) { $a.Intent = $i.Key; $a.IntentLabel = $i.Label; break } }
    # La période ne filtre la date de modification que pour « quoi de neuf ? » ;
    # ailleurs (« mon VPN coupe depuis cette semaine ») elle décrit le symptôme.
    if ($a.Intent -ne 'news') { $a.Since = ''; $a.SinceLabel = '' }
    foreach ($n in $script:BtNoise) { $norm = [regex]::Replace($norm, ('(?<![\p{L}])' + $n + '(?![\p{L}])'), ' ') }

    $words = @($norm -split "[^\p{L}\p{Nd}\-]+" | Where-Object { $_ })
    $a.Natural = ($raw -match '\?') -or ($words.Count -ge 4) -or [bool](@($words | Where-Object { $script:BtStopWords.ContainsKey($_) }).Count)

    # Expressions de plusieurs mots du dictionnaire (« mot de passe »).
    $groups = New-Object System.Collections.Generic.List[object]
    foreach ($k in $script:BtSynonyms.Keys) {
        if ($k -match ' ' -and $norm -match ('\b' + [regex]::Escape($k) + '\b')) {
            $groups.Add(@(@($k) + $script:BtSynonyms[$k] | Select-Object -Unique))
            $norm = $norm -replace ('\b' + [regex]::Escape($k) + '\b'), ' '
        }
    }
    $seen = @{}
    foreach ($w in @($norm -split "[^\p{L}\p{Nd}\-]+")) {
        if (-not $w -or $w.Length -lt 2 -or $script:BtStopWords.ContainsKey($w) -or $seen.ContainsKey($w)) { continue }
        if ($w -match '^\d+(e|er|re|[eè]me)?$') { continue }   # « 3e », « 2 » : pas discriminant
        $seen[$w] = $true
        $v = New-Object System.Collections.Generic.List[string]
        $v.Add($w)
        if ($script:BtSynonyms.Contains($w)) { foreach ($s in $script:BtSynonyms[$w]) { $v.Add($s) } }
        # Mot long : variante « racine* ». Sigle / mot court (« CIP », « CATI ») : variante
        # « cip* » pour retrouver aussi les formes accolées ou déclinées (CIP2, CATIs,
        # CIP_CATI…), qu'un ET strict sur le mot exact laissait de côté.
        $stem = Get-BtStem $w
        if ($stem) { $v.Add($stem) }
        elseif ($w.Length -ge 3 -and $w.Length -le 6 -and $w -match '^[\p{L}\p{Nd}]+$') { $v.Add($w + '*') }
        # Notion déjà couverte (« imprimer » puis « imprimante ») : fusion des variantes.
        $dup = $null
        foreach ($g in $groups) { if (@($g | Where-Object { $v.Contains($_) }).Count) { $dup = $g; break } }
        if ($dup) { $groups[$groups.IndexOf($dup)] = @(@($dup) + @($v) | Select-Object -Unique); continue }
        $groups.Add(@($v | Select-Object -Unique))
    }
    # Au-delà de 5 notions, on garde les plus longues (les plus discriminantes).
    if ($groups.Count -gt 5) { $groups = @($groups | Sort-Object { -([string]$_[0]).Length } | Select-Object -First 5) }
    # Copie explicite : un tableau de tableaux ne doit pas être « aplati » par le pipeline.
    $arr = New-Object object[] $groups.Count
    for ($i = 0; $i -lt $groups.Count; $i++) { $arr[$i] = [string[]]$groups[$i] }
    $a.Groups = $arr
    $a.Keywords = ((@($a.Phrases) + @($a.Groups | ForEach-Object { $_[0] })) -join ' ').Trim()
    return [pscustomobject]$a
}

# Clause CQL « mots-clés ». Stricte : toutes les notions ; -Relaxed : au moins une.
# -Field title : même clause restreinte aux titres (bloc « titre » affiché en premier).
function Format-BtKeywordClause {
    param($Analysis, [switch]$Relaxed, [ValidateSet('text', 'title')][string]$Field = 'text')
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Analysis.Phrases) { $parts.Add(('{0} ~ "\"{1}\""' -f $Field, (ConvertTo-BtCqlString $p))) }
    foreach ($g in $Analysis.Groups) {
        $alts = @($g | ForEach-Object { '{0} ~ "{1}"' -f $Field, (ConvertTo-BtCqlString $_) })
        $parts.Add($(if ($alts.Count -gt 1) { '(' + ($alts -join ' OR ') + ')' } else { $alts[0] }))
    }
    if (-not $parts.Count) {
        # « Quoi de neuf ? » sans sujet : pas de clause, le tri par date suffit.
        if ($Analysis.Intent -eq 'news') { return '' }
        return ('{0} ~ "{1}"' -f $Field, (ConvertTo-BtCqlString $Analysis.Raw))
    }
    return ($parts -join $(if ($Relaxed) { ' OR ' } else { ' AND ' }))
}

# Résumé affiché au-dessus des résultats (« Compris : … »).
function Get-BtUnderstanding {
    param($Analysis, [bool]$Relaxed)
    if (-not $Analysis) { return '' }
    $bits = @()
    if ($Analysis.IntentLabel) { $bits += $Analysis.IntentLabel }
    $terms = @($Analysis.Phrases | ForEach-Object { "« $_ »" }) + @($Analysis.Groups | ForEach-Object {
        $syn = @($_ | Select-Object -Skip 1 | Where-Object { $_ -notmatch '\*$' })
        if ($syn.Count) { '{0} (+{1})' -f $_[0], ($syn -join ', ') } else { [string]$_[0] } })
    if ($terms.Count) { $bits += ($terms -join ' · ') }
    if ($Analysis.SinceLabel) { $bits += $Analysis.SinceLabel }
    $txt = $bits -join '  —  '
    if ($Relaxed) { $txt += '   (aucune fiche ne réunit toutes ces notions : résultats élargis)' }
    return $txt
}
