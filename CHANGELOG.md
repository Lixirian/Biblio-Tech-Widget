# Historique des versions

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
