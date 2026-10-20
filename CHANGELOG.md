# Historique des versions

## 1.1.17 — 2026-10-20

- **Copilot retiré** (demande de l'utilisateur) : dossier `copilot-agent/` supprimé ;
  `CopilotAgentUrl` (config), préférence `CopilotLicensed` (state), action `copilot`, bouton
  « Demander à Copilot » du bandeau « Compris » et case du menu retirés. L'assistant local
  (`BtAssist.ps1`) reste seul en charge du langage courant. Ligne Copilot retirée de la note DSI.

## 1.1.16 — 2026-10-20

- **Mises à jour signées** (risque traité : compte GitHub compromis -> version piégée diffusée à
  tous les postes ; l'empreinte SHA-256 venait du même `latest.json` que le zip). Clé RSA 3072
  générée par `build-release.ps1 -NewSigningKey`, privée dans `%USERPROFILE%\.biblio-tech-signing\`
  (DPAPI utilisateur, hors dépôt / GitHub / SynologyDrive ; `.gitignore` : `*.backup`, `*.dpapi`).
  Le build signe « BiblioTech-Widget|<version>|<SHA-256> » (champ `sig` de latest.json) et vérifie
  que la clé publique livrée (`Config.ReleasePublicKey`, `$ReleasePublicKey` du lanceur) correspond.
  L'appli (`Test-BtReleaseSignature`) et le lanceur (`Test-ReleaseSignature`, embarqué dans
  `Biblio-Tech.cmd` : un poste NEUF vérifie déjà) REFUSENT un zip sans empreinte, sans signature
  ou mal signé ; le lanceur n'installe plus de version plus ancienne que l'installée.
  Changement de PC : `-ExportSigningKey` (sauvegarde AES-256 + HMAC, PBKDF2-SHA256 600 000 it.,
  mot de passe ≥ 12 car.) / `-ImportSigningKey -KeyBackup <fichier>` (contrôle de correspondance).
  Tests : 6 cas (valide, zip modifié, version modifiée, sans signature, autre clé, illisible) sur
  les DEUX fonctions ; export / mauvais mot de passe refusé / import identique.
  Transition : c'est le code INSTALLÉ qui vérifie -> 1.1.16 s'installe encore sans contrôle de
  signature, les versions suivantes sont protégées.

## 1.1.15 — 2026-10-20

- **Tuiles sans texte** : sur l'accueil du site, l'émoji est souvent un lien À PART collé devant
  le vrai lien (même adresse) -> tuile vide. `collect()` (BtHomeJs) rattache un lien « émoji seul »
  (`!/[\p{L}\p{N}]/u`) au lien suivant ; `linkOf` accepte un lien dont seul l'émoji est lisible.
- **Doublons** (« Installer une Borne eVote » ×5 dans « Commentaires de l'espace ») : la liste des
  commentaires pointe vers la même page avec `?focusedCommentId=…` ; dédoublonnage par id de page.
- **Ordre** : 1re section (profil) -> « Biblio-TECH met en avant » (`Add-BtHighlightTiles`) ->
  autres sections. Vérifié dans WebView2 sur une fausse page Confluence (émoji séparé, 5 liens de
  commentaires vers 1 page) et en mode démo.

## 1.1.14 — 2026-10-20

- **Accueil selon le profil** (ex. TAM) : la page d'accueil du site affiche des blocs propres au
  profil de l'utilisateur. `BtHomeJs` lit sa MISE EN PAGE telle que l'utilisateur la voit
  (`layoutOf`) : de préférence la page réellement affichée dans le WebView principal
  (`#main-content`, éléments masqués exclus), sinon `body.view` (rendu serveur pour l'utilisateur
  connecté). Encadrés `div.panel` -> « Biblio-TECH met en avant » (date « jj/mm » séparée du titre) ;
  titres h1-h4 suivis de liens -> sections de tuiles (« TAM / Gestionnaire en Production »…).
  Émojis Confluence (`img[data-emoji-id|data-emoji-fallback]`) repris comme icônes ; pièces
  jointes et profils exclus ; lien externe -> navigateur ; lien de page -> rubrique (sous-pages)
  ou, sans sous-page, lecteur. « Toutes les rubriques » devient une tuile des accès rapides ;
  repli sur l'ancienne grille si la mise en page est illisible. Vérifié dans WebView2 sur une
  fausse page au balisage Confluence (section d'un autre profil masquée : exclue). Journal :
  `[ACCUEIL] Mise en page (source) : N mis en avant ; sections : …`.
- Recherche « au moins un mot, comme le site » essayée puis écartée à la demande de
  l'utilisateur : on garde TOUS les mots exigés, titre complet en tête. Le JS accepte
  désormais une liste de blocs prioritaires (`P.prio`), aujourd'hui le seul bloc « titre ».
- **Thème des pages = thème Windows** (`AppsUseLightTheme`, relu toutes les 3 s par
  `Step-BtTheme`) : `CoreWebView2Profile.PreferredColorScheme` (pages qui gèrent
  `prefers-color-scheme` : tableau de bord, désormais en variables CSS clair/sombre) + pour le
  LECTEUR, feuille « sombre » injectée dès la création du document (`BtDarkPageJs` : inversion +
  rotation de teinte, images rétablies ; retirée si la page est déjà sombre ; bascule en direct
  sur changement de thème). Pièges corrigés en test : `location.host` contient le port
  (-> `hostname`) ; `documentElement` absent à la création du document (-> MutationObserver).
  Captures : sombre et retour au clair sans rechargement.

## 1.1.13 — 2026-10-20

- **Page Confluence visible après la validation SSO** : la fenêtre de connexion n'était masquée
  qu'après la sonde d'identité (~1,5 s + chargement). Nouveau `NavigationStarting` : dès qu'une
  navigation de 1er niveau repart vers l'hôte Confluence (hors `login/dologin/authenticate.action`),
  la fenêtre passe hors écran (sans interrompre la navigation) et la fenêtre principale reprend le
  focus ; une redirection finale vers une page de connexion la remontre. « Se connecter » ne montre
  plus la fenêtre avant d'atterrir sur l'IdP. Vérifié avec faux Confluence + faux IdP (validation
  après 9 s) et capture d'écran continue : IdP visible pendant la validation, page Confluence
  jamais affichée ; relancement avec le même profil : connexion directe sans fenêtre.
- **Émoji en tête de titre** (« 📢u-DOM ») : WPF le collait au texte. `Split-BtTitleEmoji`
  le sépare (symboles, pictogrammes, paires de substitution, ZWJ / sélecteurs de variante) ;
  il devient l'icône de la tuile et de l'en-tête de rubrique (police Segoe UI Emoji) et
  disparaît du titre et du fil d'Ariane.
- **« L'appli ne répond pas » pendant une requête** : deux gros consommateurs du thread de la
  fenêtre. (1) L'analyse des catégories (~20 s après la connexion) : `ConvertFrom-Json` de
  plusieurs Mo + fusion + journal + rapport sur ~8 000 fiches = ≥ 10 s de gel. Désormais : sonde
  en mode brut (`New-BtProbe -Raw` : seuls state/id lus en tête), décodage
  (`JavaScriptSerializer`), fusion, journal, rapport ET arborescence dans une tâche de fond
  (`Start-BtBgJob` / `Receive-BtBgJob`, BtCommon : runspace séparé, copies des fonctions,
  journal tamponné) ; l'index est aussi préchargé ainsi au démarrage. Mesure sur 8 000 fiches
  simulées : 8,8 s de traitement hors fenêtre, tick de pompe ≤ 46 ms. (2) Rendu : ~9 ms par
  carte, jusqu'à 120 cartes depuis 1.1.11 -> 25 au départ (`Search.ShowN`), « Afficher plus »
  montre d'abord le reçu puis interroge Confluence ; rubriques par lots de 25.
  `Write-BtLog` via `AppendAllText`. Diagnostic : `[LENT]` (étape de pompe ou affichage > 250 ms),
  `[FOND]` (durée des tâches de fond).

## 1.1.12 — 2026-10-20

- **Tuiles qui n'ouvraient rien** : l'ouverture était branchée sur `Completed` d'une
  `DoubleAnimation` APRÈS `BeginAnimation` ; WPF anime une copie figée, l'événement ne se
  déclenchait jamais (reproduit hors écran). Ouverture désormais immédiate au relâchement du
  clic (la page suivante garde son glissement). Ombre animée (`DropShadowEffect`) retirée :
  coûteuse en rendu logiciel / poste virtualisé. Sous-pages d'une rubrique chargées sans
  attendre l'aperçu de l'accueil ; consignes affichées par lots de 40 (« Afficher plus »).
- **SSO à chaque lancement** : les cookies de session Confluence / IdP (sans échéance) étaient
  effacés par WebView2 à la fermeture. `Step-BtKeepSession` (BtNet, pompe, toutes les 5 min
  une fois connecté) leur donne une échéance `SessionKeepHours` (12 h) dans le magasin de
  cookies du profil WebView2 — domaines de `AuthAllowlist` seulement, aucune valeur lue ni
  copiée ailleurs ; l'expiration serveur reste maître. Vérifié avec un serveur local : cookie
  perdu au relancement sans le correctif, présent avec. Journal : `[AUTH] Session conservée`.

## 1.1.11 — 2026-10-20

- **Page d'accueil de référence** : `HomePath` = `/spaces/KM/pages/500662444/Bienvenue+dans+votre+Biblio-TECH`,
  nouveau `HomePageId` (`500662444`) dans `config.ps1` (SSO, lien navigateur, tuile « Page d'accueil »).
- **Accueil en tuiles** (nouveau `lib/BtHome.ps1`, l'aperçu quitte `BtBrowse.ps1`) : accès rapides
  (dernières news = billets de l'espace de la page d'accueil, nouvelles consignes, plus commentées,
  mises à jour récentes, page d'accueil) + une tuile par sous-page de la page d'accueil (lue via
  `/rest/api/content/<id>/child/page`, aucune liste en dur). Survol : zoom, ombre colorée, icône
  qui pivote, flèche ; clic : enfoncement puis rebond, la « page suivante » s'ouvre à la fin de
  l'animation (glissement + fondu). Rubrique : sous-rubriques en tuiles, consignes en cartes ;
  sans sous-page -> lecteur. Retour : ←, Échap, bouton précédent de la souris, onglet Accueil.
  Les longues listes (mises à jour récentes, aperçus) passent derrière leurs tuiles.
- **Recherche = consignes** : `ContentTypes = @('page')` ; « récents » sans blogs ; une pièce
  jointe remontée par le repli DOM est écartée ; les plus commentées ne comptent que les pages.
- **« CIP CATI »** : chaque sigle/mot court (3 à 6 car.) reçoit la variante `mot*`
  (`(text ~ "cip" OR text ~ "cip*") AND (text ~ "cati" OR text ~ "cati*")`) ; bloc « titre »
  porté à 100 fiches. Hypothèses principales (non vérifiables hors réseau) : formes accolées
  (CIP2, CIP_CATI…) et pièces jointes qui occupaient la 1re page. À confirmer avec le journal
  `[SEARCH]` sur le terrain.
- Mode démo : rubriques/news fictives ; `BT_TEST_TILE=<n>` ouvre la n-ième rubrique.

## 1.1.10 — 2026-10-16

- **Épinglage dans la barre des tâches** : Windows épinglait le processus (powershell.exe,
  son icône). `Set-BtWindowRelaunch` (BtCommon, type C# `BtTaskbar` :
  `SHGetPropertyStoreForWindow`) pose sur chaque fenêtre `System.AppUserModel.RelaunchCommand`
  (wscript + lanceur), `RelaunchDisplayNameResource` (« Biblio-Tech »),
  `RelaunchIconResource` (`icone app.ico,0`) puis `System.AppUserModel.ID`
  (`$script:BtAppId`, identique à l'AUMID du processus). Vérifié par relecture des propriétés.
  Une épingle existante doit être détachée puis recréée.

## 1.1.9 — 2026-10-16

- **Langage courant** (`BtAssist.ps1`) : « donne moi tout ce qui concerne les bornes evote »
  donnait les notions `donne · moi · concerne · bornes · evote`, toutes OBLIGATOIRES (ET) ->
  1 seul résultat. Ajout des formules de demande au bruit (`donne-moi`, `sors-moi`, `tout ce
  qui concerne`, `les infos sur`, `à propos de`, `au sujet de`, `relatif à`, `y a-t-il`…) et
  des mots vides associés (moi, concerne, infos, documentation, est-ce…). Vérifié sur
  11 formulations : toutes donnent `bornes · evote` comme la saisie par mots-clés.

## 1.1.8 — 2026-10-16

- **Reconnexion automatique à l'ouverture** : le cookie de session Confluence est un cookie de
  session (perdu à la fermeture) et la vérification par API (1.1.5) ne relançait jamais le SSO
  -> connexion manuelle à chaque ouverture. Désormais `Start-BtSilentLogin` suit le parcours
  SSO dans la fenêtre cachée : session IdP valide -> connecté sans rien afficher ; page de
  l'IdP stable depuis `AuthPromptSec` (6 s) -> `Show-BtLoginPrompt` montre la fenêtre SUR
  CETTE PAGE (aucune interruption / rechargement : pas de demande SAML périmée). Confluence
  anonyme sans redirection -> une tentative via `login.action` (`LoginNavDone`), puis fenêtre.
  Reconnexions (réseau, session expirée) : même tentative silencieuse.
- Validé contre un faux Confluence + faux IdP locaux (HttpListener) : 1re ouverture = fenêtre
  à 6 s puis une seule validation ; réouverture avec session IdP valide = reconnexion < 1 s.

## 1.1.7 — 2026-10-16

- Filtres de type (Pages / Blogs / Pièces jointes) et de tri (Pertinence / Plus récents)
  retirés de la barre (inutiles) : onglets **Accueil** / **Catégories** à la place. `State.Type`
  et `State.Sort` forcés à `all` / `relevance` au démarrage (un ancien choix mémorisé ne doit
  plus filtrer sans être visible). Le filtre d'espace reste si `SpaceKey` est configuré.

## 1.1.6 — 2026-10-16

- **Index des catégories incrémental** (`lib/BtCategories.ps1`, local) : `categories-index.json`
  (métadonnées : titre, ancêtres, étiquettes, type, lien, date). À chaque ouverture (20 s après
  la connexion) : fiches `lastmodified >= dernière analyse - 1 j` + liste légère des id
  (suppressions, si complète) ; parcours complet si index absent / > 7 jours / menu
  « Reconstruire ». Journal `categories-journal.log` (catégories + / - / ~, fiches + / - / >).
  Rapport `analyse-categories.txt` régénéré depuis l'index. Sérialisation JavaScriptSerializer.
- **Onglet « Catégories »** (`lib/BtBrowse.ps1`, puce dans la barre de filtres) : arborescence
  de l'index (niveau 1 = page sous l'accueil de l'espace), nœuds dépliables, page de rubrique
  « ouvrir ↗ », fiches -> lecteur (Ctrl+clic : navigateur), 200 fiches max par nœud.
- **Accueil** : « Les plus commentées » et « Nouvelles fiches » des 30 derniers jours (sonde
  `__btHome`, rafraîchie toutes les 15 min).
- **Tableau de bord** : sans réponse (1re réponse d'un autre contributeur, réponses postées
  après la période incluses), délai médian / moyen, % < 48 h, comparaison période précédente
  (`/rest/api/search` totalSize), jours × heures, activité éditoriale (créées / dernière
  modification), nouvelles consignes, fiches à revoir (> 12 mois, `version.when`), rubriques
  (`id in (…)` + ancêtres), « J'aime » (`/rest/likes/1.0/content/{id}/likes`, journalisé).
  Export Excel : 11 feuilles, 6 graphiques, échelle de couleurs jours × heures.
- **Pastille de MAJ rapide** : `latest.json` joint à la release et lu via
  `github.com/…/releases/latest/download/latest.json` (repli raw) ; contrôle toutes les
  2 min et au retour sur la fenêtre ; bulle de notification.

## 1.1.5 — 2026-10-16

- **Double connexion corrigée** : la vérification silencieuse (démarrage, reconnexion,
  réseau revenu) navigue vers `CheckUrl` = `/rest/api/user/current` au lieu de l'accueil ;
  elle ne déclenche plus de demande SAML que l'appli coupait (`about:blank`) et qui faisait
  échouer la 1re validation manuelle. L'accueil n'est chargé qu'au clic « Se connecter ».
- Connexion manuelle : plus aucune renavigation vers `login.action` (2e parcours SSO). Si la
  session n'est pas encore reconnue, simple re-vérification (`InfoAt`, 3 essais / 2 s) ; sonde
  différée de 1,5 s après chaque page ; pages `/plugins/servlet/(saml|sso|oidc|oauth)` ignorées.

## 1.1.4 — 2026-10-16

- **Icône de la barre des tâches** : `Window.Icon` était ignorée (fenêtre WPF hébergée par
  powershell.exe + AppUserModelID explicite). `Set-BtWindowIconNative` (BtCommon) pose
  l'icône en Win32 (`WM_SETICON` 32/16 px depuis `icone app.ico`) ; `Register-BtWindowIcon`
  la ré-applique sur SourceInitialized, ContentRendered, chaque réaffichage et à
  900/2500/6000 ms (même correctif que SNOW 1.5.17). Fenêtres : principale, lecteur, connexion.
- **Tableau de bord** (`lib/BtDashboard.ps1`, bouton `DashBtn` + menu) : fenêtre WebView2 qui
  charge `/rest/api/user/current` puis y injecte une page (SVG intégré, sans librairie) ;
  `type = comment` par plage de dates (`created`), réponses = commentaire ayant un ancêtre
  commentaire ; pages les plus commentées, contributeurs ; « consignes phares » via
  `/rest/confanalytics/1.0/...` si disponible (essais journalisés `[DASH]`), sinon repli sur
  les plus commentées. Pont `chrome.webview.postMessage` -> journal. Max `DashMaxComments`.
- **Export Excel** (COM, Excel du poste) : Synthèse (indicateurs + 3 graphiques natifs),
  Par jour, Pages commentées, Consignes phares, Contributeurs ; titres en liens. Écriture par
  blocs `object[,]` ; `NumberFormat` lu dans la langue d'Excel (`jj/mm/aaaa` puis `dd/mm/yyyy`).
  Fichier dans Téléchargements, ouvert à la fin.
- **Analyse des catégories** (`lib/BtCategories.ps1`, diagnostic LOCAL, rien n'est envoyé) :
  métadonnées seulement (ancêtres, étiquettes, espace, type, titres) jusqu'à `CategScanMax`
  pages -> `analyse-categories.txt` (arborescence niveaux 0-2, chemins, étiquettes et
  combinaisons, préfixes émoji / « X - », 2 premiers mots). Automatique une fois par version
  (45 s après connexion, `State.CategScanVersion`) + menu.

## 1.1.3 — 2026-10-16

- **Titres en tête** (tri « Pertinence », 1re page) : requête CQL parallèle restreinte aux
  titres (`Get-BtCql -TitleOnly`, `Format-BtKeywordClause -Field title`, 50 max) ; ses fiches
  passent avant les résultats Confluence, sans doublon (`titleIds`, retirés aussi des pages
  suivantes). Ignoré en tri « Plus récents », relance élargie ou « quoi de neuf ». En cas
  d'échec de cette requête, l'ordre Confluence est conservé (`[SEARCH] Replis : titre…`).

## 1.1.2 — 2026-10-16

- **Fichier unique `Biblio-Tech.cmd`** (racine du dépôt + asset de release) à la place de
  `BiblioTech-Installer.zip` : en-tête batch qui exécute `launcher\bootstrap.ps1` embarqué
  (généré par `build-release.ps1`). Installe / met à jour / répare puis lance ; `/repair` force.
- Chaque version reste livrée en `dist\BiblioTech-Widget_version<X>.zip` (qui contient aussi
  `Biblio-Tech.cmd`) ; les zips des versions précédentes sont déplacés dans `Archives\`.

## 1.1.1 — 2026-10-16

- **Connexion manuelle** : plus de SSO automatique en boucle. Au démarrage, seule une session
  déjà ouverte (cookie) est réutilisée en silence ; sinon l'appli s'arrête (`about:blank`) et
  attend le clic « Se connecter » (`Start-BtInteractiveLogin`). Pendant la validation, aucune
  renavigation automatique (`Invoke-BtReconnect` ignoré, une seule redirection `login.action`).
- **Réparation / MAJ au lancement** : les raccourcis pointent vers
  `%LOCALAPPDATA%\BiblioTech-Widget\launcher\Biblio-Tech.vbs` → `bootstrap.ps1`, qui compare la
  version installée à `latest.json` (délai 5 s) et réinstalle automatiquement si la copie est
  absente, incomplète ou plus ancienne (arrêt de l'instance en cours, SHA-256). Le lanceur est
  livré dans chaque zip (`launcher\`) et resynchronisé par l'appli (`Sync-BtLauncher`).
  Relancer `Biblio-Tech.cmd` met aussi à jour une installation existante (plus besoin de `/repair`).

## 1.1.0 — 2026-10-15

- **Application fenêtrée** au lieu de la barre ancrée (AppBar) : barre de titre intégrée,
  redimensionnement et ancrage Windows natifs, taille/position mémorisées. Fermer (X) masque
  la fenêtre dans la zone de notification ; relancer le raccourci la réaffiche.
- **Accueil Biblio-Tech** : la page d'atterrissage est la racine de Confluence et la recherche
  porte sur tout Biblio-Tech (`SpaceKey` vide ; filtre d'espace optionnel).
- **Recherche en langage courant** (`lib/BtAssist.ps1`, local, sans IA externe) : intention,
  mots vides, synonymes métier, racines, période (« cette semaine »), bandeau « Compris : … »,
  relance élargie automatique si aucune fiche ne réunit toutes les notions.
- **Agent Microsoft 365 Copilot** (`copilot-agent/`) pour les utilisateurs licenciés : paquet
  d'agent déclaratif + connecteur Confluence On-premises ; bouton « Demander à Copilot ».
- Icône de l'application (`icone app.ico` / `.png`).
## 1.0.0 — 2026-10-15

Première version.

- Recherche par mots-clés dans l'espace Confluence KM via la session SSO (WebView2,
  requêtes same-origin, aucun identifiant stocké). Cascade REST search → REST content →
  scraping DOM.
- Barre ancrée (AppBar) en haut, à gauche ou à droite ; raccourci global Ctrl+Alt+K ;
  icône de notification.
- Filtres (espace KM / tout Confluence, type, tri), extraits surlignés, étiquettes,
  dates relatives, pagination « Afficher plus ».
- Accueil : pages épinglées, recherches récentes, dernières mises à jour de l'espace.
- Lecteur intégré avec mode lecture.
- Installation par lanceur + mises à jour automatiques depuis GitHub (pastille, notes de
  version, vérification SHA-256, updater détaché).
