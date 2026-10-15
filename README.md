# Biblio-Tech Widget

Widget de bureau Windows pour **rechercher par mots-clés dans la base de connaissances
Confluence (espace KM)**, avec la session SSO déjà ouverte sur le poste. Il fonctionne
sur le même principe que le *SNOW Widget* : PowerShell + WPF + WebView2, aucun `.exe`,
aucun identifiant ni jeton stocké.

## Installation

1. Télécharger **`BiblioTech-Installer.zip`** depuis la [dernière release](../../releases/latest).
2. Extraire l'archive, puis double-cliquer sur **`Biblio-Tech.cmd`**.
   - La dernière version est téléchargée depuis GitHub, son empreinte SHA-256 est vérifiée,
     puis elle est installée dans `%LOCALAPPDATA%\BiblioTech-Widget\app`.
   - Les raccourcis *Biblio-Tech Widget* sont créés dans le menu Démarrer et sur le Bureau.
3. Les lancements suivants passent par le raccourci, qui démarre la copie locale.

## Utilisation

| Action | Comment |
|---|---|
| Ouvrir la recherche depuis n'importe où | **Ctrl+Alt+K** (ou clic sur l'icône de notification) |
| Lancer la recherche | Taper : elle part automatiquement (ou **Entrée**) |
| Ouvrir un résultat | Clic → lecteur intégré · **Ctrl+clic** → navigateur |
| Filtrer | Espace KM / tout Confluence · type · pertinence / plus récents |
| Garder une page sous la main | 📌 Épingler (visible sur l'accueil du widget) |
| Déplacer la barre | Bouton ⇄ (haut → droite → gauche) ou menu |

## Mises à jour

Elles sont automatiques, comme pour le SNOW Widget. L'application lit régulièrement
`latest.json` sur ce dépôt. Quand une version plus récente existe, une pastille jaune
**« Mise à jour »** apparaît dans la barre. Au clic, les nouveautés s'affichent ; après
confirmation, le zip de la release est téléchargé et son SHA-256 vérifié. Un updater
détaché remplace alors la copie locale puis relance l'application.

## Fonctionnement technique

- Un WebView2 (profil dans `%LOCALAPPDATA%\BiblioTech-Widget\webview2`) charge Confluence
  et déroule le SSO (Kerberos/Negotiate sur `*.sncf.fr`). Une fenêtre de connexion
  n'apparaît que si le fournisseur d'identité demande une interaction.
- Les recherches sont des requêtes **same-origin exécutées dans la page Confluence**
  (cookie de session), en CQL, avec une cascade de replis :
  `/rest/api/search` → `/rest/api/content/search` → scraping de `dosearchsite.action`.
- Journal : `%LOCALAPPDATA%\BiblioTech-Widget\app_debug.log`.

## Publier une version (mainteneur)

1. Incrémenter `Version` dans `BiblioTech-Widget-PS/config.ps1`.
2. Ajouter les notes dans `BiblioTech-Widget-PS/releases.json`.
3. `powershell -ExecutionPolicy Bypass -File build-release.ps1`
   (zip, release GitHub, puis `latest.json` ; `-NoPublish` pour un essai local).
