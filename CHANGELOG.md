# Historique des versions

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
