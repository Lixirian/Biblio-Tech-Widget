# ============================================================================
#  Configuration centrale du Biblio-Tech Widget (PowerShell + WPF + WebView2).
#  Un seul fichier à éditer pour changer d'instance Confluence, d'espace ou de
#  dépôt de mise à jour.
# ============================================================================

$Config = @{
    # Version de l'application. À INCRÉMENTER à chaque publication (build-release.ps1
    # lit cette valeur pour nommer le zip, la release GitHub et latest.json).
    Version            = '1.1.21'

    # ----- Confluence -----
    # URL de l'instance (sans slash final).
    BaseUrl            = 'https://confluence.apps.eul.sncf.fr'
    # Vide = recherche dans tout Biblio-Tech. Une clé d'espace (ex. 'KM') ajoute un
    # filtre « Espace <clé> » et limite l'accueil « Mis à jour récemment » à cet espace.
    SpaceKey           = ''
    # Page d'accueil Biblio-Tech (« Bienvenue dans votre Biblio-TECH ») : atterrissage du
    # SSO au démarrage, lien « Ouvrir Biblio-Tech dans le navigateur » et tuile « Page d'accueil ».
    HomePath           = '/spaces/KM/pages/500662444/Bienvenue+dans+votre+Biblio-TECH'
    # Identifiant de cette page : ses sous-pages deviennent les tuiles « Rubriques » de
    # l'accueil, et les « Dernières news » sont les billets de blog de son espace.
    HomePageId         = '500662444'
    # Domaines autorisés pour le SSO Windows intégré (Kerberos/Negotiate).
    AuthAllowlist      = '*.sncf.fr'

    # ----- Recherche -----
    # Types de contenu remontés par la recherche : les CONSIGNES (pages) uniquement.
    # Pièces jointes, billets de blog, commentaires… sont exclus (outil de recherche de
    # consignes, pas de fichiers). Les news restent accessibles par la tuile de l'accueil.
    ContentTypes       = @('page')
    PageSize           = 20      # résultats par page (« Afficher plus » charge la suite)
    CategScanMax       = 8000    # index local des catégories : nb max de fiches (parcours complet hebdomadaire)
    DashMaxComments    = 5000    # tableau de bord : nb max de commentaires chargés par plage de dates
    RecentCount        = 12      # pages « mises à jour récemment » sur l'accueil
    MinQueryLength     = 2       # nb de caractères avant la recherche automatique
    SearchDebounceMs   = 450     # pause de frappe avant de lancer la recherche
    FetchTimeoutSec    = 20      # délai max d'une requête (par stratégie)
    HistoryMax         = 15      # recherches récentes mémorisées
    # 'auto' = API REST same-origin (session SSO) puis repli scraping DOM ;
    # 'dom'  = scraping de la page de recherche uniquement.
    SearchStrategy     = 'auto'
    # Vérification périodique de la session (minutes).
    SessionCheckMin    = 20
    # Session SSO conservée après fermeture de l'appli (heures ; 0 = revalider à chaque
    # lancement). Plafond côté poste : l'expiration réelle reste celle du serveur / de l'IdP.
    SessionKeepHours   = 12
    AuthPromptSec      = 6       # SSO silencieux bloqué sur une page de l'IdP depuis N s -> fenêtre de connexion

    # ----- Fenêtre -----
    # Taille au premier lancement (ensuite : taille/position mémorisées dans state.json).
    WindowWidth        = 980
    WindowHeight       = 740
    # Raccourci global pour afficher la fenêtre, recherche prête à la saisie.
    Hotkey             = 'Ctrl+Alt+K'

    # ----- Mise à jour automatique (GitHub) -----
    # Dépôt PUBLIC 'propriétaire/nom' : lecture anonyme, AUCUN jeton stocké.
    # latest.json (branche UpdateBranch) annonce la version + l'URL du zip (asset de
    # la release) + son empreinte SHA-256 (vérifiée avant installation).
    # $false = aucune mise à jour automatique, aucun contact avec GitHub. De toute façon, une
    # copie placée HORS de %LOCALAPPDATA%\BiblioTech-Widget\app (zip complet déployé à l'unité
    # par la DSI, dans le dossier de son choix, même en lecture seule) ne se met jamais à jour
    # seule et ne contacte jamais GitHub : les nouvelles versions sont redéployées par la DSI.
    AutoUpdate             = $true
    GitHubRepo             = 'Lixirian/Biblio-Tech-Widget'
    # Clé PUBLIQUE de signature des versions (inscrite par build-release.ps1 -NewSigningKey).
    # Une mise à jour dont la signature (latest.json, champ sig) n'est pas valide pour cette
    # clé est REFUSÉE. Ce n'est pas un secret : la clé privée reste sur le poste de publication.
    ReleasePublicKey       = '<RSAKeyValue><Modulus>+yrGL/TD1Xq9ztPWRuXBh5EicDd0WSpuid7ylmqZhYDEDvqsOXwgfrrZi2pTdW65FPQy1pzLtDtz7+VEjn+fRUTR5RFanIBxhQEkL1yPl1h2dMXc5UWbTBRoF13ZI2wLxxiPhWuTpHEIxtmmHyZ/c8mpaW2xSDMvVRGgm3SOSuLrkmgm9LOFJWDRSYV8cuim0rA5X1/DUTP3LPwbkbQJYjlsxi6dYR8xJk1Fn37uQfbw9vL/TwG5LhawOKZbABax2Lf8vfYeEihcJCbu/cSQD7cPfGWjO4xDcbYVMFnTdFhrQ/5ghdWNYn1p/v7sB7ap10UHXYUiHsp10c4mQ1ltD8zPBe8tq5wRi5q2L/Or6vm2yKWZQ9hlT50Gy67UN+MTGeM6A/WGiLo7SUa1sPrFBbvDMdi539P5o+2t7w+oRKdaNHnpDhy2a0FZVl38jhbGH0BhpwO0CaqrcAe1n+0VSKaZnKpd1J/aRFA8eLTKTOm+EgRNsB4efZl67V3yOtbh</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
    UpdateBranch           = 'main'
    # Contrôle ~10 s après le lancement, puis à cette cadence (secondes, min. 60).
    UpdateCheckIntervalSec = 120
}
