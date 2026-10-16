# Historique des versions

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
