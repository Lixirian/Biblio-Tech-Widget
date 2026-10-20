# CLAUDE.md

Guidance pour Claude Code dans ce dépôt. Réponds toujours en **français**.

## Vue d'ensemble

Application fenêtrée (PowerShell 5.1 + WPF + WebView2) qui recherche, en mots-clés ou en
langage courant, dans la base de connaissances Confluence **Biblio-Tech**
(`https://confluence.apps.eul.sncf.fr`, accueil = page « Bienvenue dans votre Biblio-TECH »
de l'espace KM, recherche sur tout le site, **consignes (pages) uniquement**). Même socle que le
*SNOW Widget* (`..\Service now vue bureau`) — machines d'état non bloquantes, aucune donnée
d'identification stockée — mais **volontairement en fenêtre** (pas d'AppBar) pour cohabiter
avec lui. Distribution et mises à jour via **GitHub** (dépôt public `Lixirian/Biblio-Tech-Widget`).
Aucune intégration Copilot (agent M365 retiré en 1.1.17 à la demande de l'utilisateur).

**Contraintes (cybersécurité SNCF)** : aucun `.exe`, aucun jeton/identifiant stocké.
Les requêtes Confluence partent **de la page** chargée dans WebView2 (`fetch`
same-origin + cookie SSO). Le réseau SNCF n'est **pas joignable depuis le poste de
dev** : valider par analyse statique et par le **mode démo** (`BT_DEMO=1`).

## Lancement / test

```powershell
BiblioTech-Widget-PS\Start-BiblioTech.cmd            # normal
$env:BT_DEMO='1'; $env:BT_TEST_QUERY='vpn'; $env:BT_AUTOQUIT_SEC='20'
powershell -STA -File BiblioTech-Widget-PS\BiblioTechWidget.ps1   # démo hors réseau
```

Journal : `%LOCALAPPDATA%\BiblioTech-Widget\app_debug.log` (tags `[AUTH]`, `[SEARCH]`,
`[MAJ]`, `[PUMP]`, `[ERREUR UI]`, `[LECTEUR]`, `[DOCK]`, `[ACCUEIL]`, `[CATEG]`, `[FOND]`,
`[LENT]` = fenêtre bloquée > 250 ms). Validation syntaxique :
`[System.Management.Automation.Language.Parser]::ParseFile(...)` (faite aussi par le build).

⚠️ Les `.ps1` doivent rester en **UTF-8 avec BOM** (sinon PS 5.1 lit les accents en ANSI).

## Architecture

```
BiblioTech-Widget-PS/
  BiblioTechWidget.ps1  point d'entrée : $script:Ctx, auth SSO, pompe 200 ms, recherche
  config.ps1            instance, espace, disposition, raccourci, dépôt GitHub, Version
  releases.json         notes de version (lues par build-release.ps1)
  lib/BtCommon.ps1      P/Invoke, %LOCALAPPDATA%, journal, raccourcis/démarrage auto
  lib/BtState.ps1       state.json (filtres, historique, épinglés, mode lecture)
  lib/BtNet.ps1         WebView2 (profil partagé) + sonde générique kick -> poll
  lib/BtAssist.ps1      langage courant LOCAL : Resolve-BtQuery (intention, synonymes,
                        période), Format-BtKeywordClause (strict / -Relaxed), « Compris »
  lib/BtSearch.ps1      Get-BtCql + JS de recherche/identité
  lib/BtUi.ps1          thème, cartes de résultats (surlignage \u0001/\u0002), puces
  lib/BtWindow.ps1      fenêtre (WindowChrome), taille mémorisée, rendu, filtres, tray, hotkey
  lib/BtReader.ps1      lecteur intégré (WebView2) + mode lecture (CSS injecté)
  lib/BtUpdate.ps1      MAJ GitHub : latest.json, pastille, SHA-256, updater détaché
  lib/BtCategories.ps1  index LOCAL des catégories, incrémental (categories-index.json + journal)
  lib/BtBrowse.ps1      onglet « Catégories » (arborescence)
  lib/BtHome.ps1        accueil en TUILES (page HomePageId) : accès rapides + rubriques
                        (sous-pages lues dans Confluence), tuiles animées, pile de navigation
  lib/BtDashboard.ps1   tableau de bord (page injectée dans une origine Confluence) + export Excel (COM)
launcher/               bootstrap.ps1 + Biblio-Tech.vbs ; livrés dans chaque zip et copiés dans
                        %LOCALAPPDATA%\…\launcher : les raccourcis y pointent -> MAJ / réparation
                        auto à chaque lancement
Biblio-Tech.cmd         FICHIER UNIQUE distribué (install / MAJ / réparation / lancement) :
                        en-tête batch + bootstrap.ps1 embarqué. GÉNÉRÉ par le build (ne pas
                        éditer : modifier launcher\bootstrap.ps1). UTF-8 sans BOM, CRLF.
build-release.ps1       zip + release GitHub + latest.json (dans cet ordre)
latest.json             manifeste lu par les postes (écrit UNIQUEMENT par le build)
```

- **Thread de la fenêtre** : tout tourne sur la pompe (DispatcherTimer 200 ms). Un traitement
  lourd de DONNÉES (gros JSON, index, rapports) passe par `Start-BtBgJob` (runspace, BtCommon) ;
  les contrôles WPF ne se créent que sur le thread de la fenêtre (cartes par lots de 25).
- **Kick → poll** : `ExecuteScriptAsync` ne résout pas les promesses ; le JS dépose son
  résultat dans `window.__btSearch` / `window.__btInfo`, sondé par `Step-BtProbe`
  (filtré par `id` pour ignorer un résultat périmé).
- **Auth** : `Start-BtAuth` crée la fenêtre de connexion HORS ÉCRAN (-5000) ; elle n'est
  présentée que sur une page IdP ou `login.action`. Session validée par la sonde
  `__btInfo` (`/rest/api/user/current`, `anonymous` = non connecté) ; re-vérifiée toutes
  les `SessionCheckMin`. Une recherche en `AUTH` est remise en file et relancée après
  reconnexion.
- **Recherche** : `Request-BtSearch` (Kind `search` | `recent`) → `Step-BtSearch` →
  `Complete-BtSearch`. Cascade JS : `rest-search` → `rest-content` → `dom`.
  La saisie est analysée par `Resolve-BtQuery` ; 0 résultat en strict (≥ 2 notions) →
  relance automatique `-Relaxed` (OR des notions). Le scraping DOM reçoit `Keywords`.
- **Fenêtre** : X / Alt+F4 = `Hide-BtMainWindow` (zone de notification) ; une 2e instance
  signale `Global\BiblioTechWidgetShow` à la 1re puis s'arrête.
- **MAJ** : uniquement si `AppRoot` = `%LOCALAPPDATA%\BiblioTech-Widget\app`
  (`Test-BtInstalledCopy`) — jamais sur le dossier de dev. Les requêtes GitHub passent
  par un runspace (proxy système + identifiants Windows pour le proxy seulement).
  ⚠️ Comme pour SNOW : la logique de MAJ qui s'exécute est celle de la version
  **installée**, pas de la cible.

## Publication

1. `Version` ++ dans `config.ps1` ; 2. notes dans `releases.json` ;
3. `powershell -ExecutionPolicy Bypass -File build-release.ps1` (`-NoPublish` = essai).
Le build commit + push le code, crée la release `v<X>` (assets : zip de version +
`Biblio-Tech.cmd`), PUIS écrit/pousse `latest.json`.

**Signature** : le build SIGNE chaque version (clé privée RSA dans
`%USERPROFILE%\.biblio-tech-signing\`, DPAPI, jamais dans le dépôt) ; l'appli et le lanceur
refusent toute MAJ non signée par la clé publique `ReleasePublicKey` (config.ps1 + bootstrap.ps1).
Nouveau PC : `build-release.ps1 -ImportSigningKey -KeyBackup <fichier>` (sauvegarde faite avec
`-ExportSigningKey`). Ne JAMAIS régénérer la clé (`-NewSigningKey`) sans nécessité : les postes
installés refuseraient les MAJ jusqu'à réinstallation via `Biblio-Tech.cmd`. Ajouter une entrée en tête
de `CHANGELOG.md` à chaque version.

## Points à valider sur le terrain (réseau SNCF)

- La stratégie réellement utilisée (`source :` dans le pied du panneau / `[SEARCH] OK via`).
  Si `rest-search` échoue, les replis sont journalisés (`[SEARCH] Replis`).
- Les sélecteurs du scraping DOM (`viaDom` dans `BtSearch.ps1`) si les API REST sont bloquées.
- Le CSS du mode lecture (`Get-BtReaderCssJS`) selon la version de Confluence DC.
- L'accès à `raw.githubusercontent.com` / `github.com` via le proxy de l'entreprise.
