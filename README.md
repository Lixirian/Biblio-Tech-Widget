# Biblio-Tech Widget

Application Windows pour **rechercher dans la base de connaissances Confluence Biblio-Tech**,
en mots-clés ou **en langage courant** (« mon VPN se coupe sans arrêt, que faire ? »), avec
la session SSO déjà ouverte sur le poste. Même socle technique que le *SNOW Widget*
(PowerShell + WPF + WebView2, aucun `.exe`, aucun identifiant ni jeton stocké), mais en
**fenêtre classique** pour bien cohabiter avec lui.

## Installation

1. Télécharger le fichier unique **[`Biblio-Tech.cmd`](../../raw/main/Biblio-Tech.cmd)**
   (aussi joint à chaque [release](../../releases/latest)) — rien à extraire.
2. Double-cliquer dessus.
   - La dernière version est téléchargée depuis GitHub, son empreinte SHA-256 est vérifiée,
     puis elle est installée dans `%LOCALAPPDATA%\BiblioTech-Widget\app`.
   - Les raccourcis *Biblio-Tech Widget* sont créés dans le menu Démarrer et sur le Bureau.
3. Les lancements suivants passent par le raccourci : à chaque démarrage, l'application est
   mise à jour ou réparée automatiquement si besoin. Relancer `Biblio-Tech.cmd` fait de même
   (`Biblio-Tech.cmd /repair` force une réinstallation).

## Utilisation

| Action | Comment |
|---|---|
| Afficher Biblio-Tech depuis n'importe où | **Ctrl+Alt+K**, clic sur l'icône de notification ou relance du raccourci |
| Chercher | Mots-clés ou phrase en langage courant : la recherche part automatiquement (ou **Entrée**) ; le bandeau **Compris** montre l'intention et les synonymes retenus |
| Ouvrir un résultat | Clic → lecteur intégré · **Ctrl+clic** → navigateur |
| Filtrer | Type (pages, blogs, pièces jointes) · pertinence / plus récents |
| Garder une page sous la main | 📌 Épingler (visible sur l'accueil) |
| Fermer | **X** masque la fenêtre (l'appli reste prête dans la zone de notification) · **… > Quitter** l'arrête |
| Licence Microsoft 365 Copilot | **… > J'ai une licence Microsoft 365 Copilot** : bouton **Demander à Copilot** vers l'agent Biblio-Tech |

## Recherche en langage courant

- **Sans licence Copilot** : assistant **local** (`lib/BtAssist.ps1`), sans IA externe ni coût.
  Il repère l'intention (incident, procédure, nouveautés…), retire les mots vides, ajoute
  les synonymes métier et les variantes (`déconnex*`) et tient compte d'une période
  (« cette semaine »). Si aucune fiche ne réunit toutes les notions, il élargit tout seul.
- **Avec licence Microsoft 365 Copilot** : agent Copilot **Biblio-Tech** (`copilot-agent/`),
  qui répond en résumant les fiches et en citant les sources. Son déploiement relève de la
  DSI : voir `copilot-agent/LISEZMOI-DSI.md`.

## Mises à jour

Elles sont automatiques, comme pour le SNOW Widget. L'application lit régulièrement
`latest.json` sur ce dépôt. Quand une version plus récente existe, une pastille jaune
**« Mise à jour »** apparaît dans la barre. Au clic, les nouveautés s'affichent ; après
confirmation, le zip de la release est téléchargé et son SHA-256 vérifié. Un updater
détaché remplace alors la copie locale puis relance l'application.

## Fonctionnement technique

- Un WebView2 (profil dans `%LOCALAPPDATA%\BiblioTech-Widget\webview2`) charge l'accueil Biblio-Tech
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
