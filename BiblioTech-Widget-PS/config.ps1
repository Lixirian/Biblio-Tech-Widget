# ============================================================================
#  Configuration centrale du Biblio-Tech Widget (PowerShell + WPF + WebView2).
#  Un seul fichier à éditer pour changer d'instance Confluence, d'espace ou de
#  dépôt de mise à jour.
# ============================================================================

$Config = @{
    # Version de l'application. À INCRÉMENTER à chaque publication (build-release.ps1
    # lit cette valeur pour nommer le zip, la release GitHub et latest.json).
    Version            = '1.0.0'

    # ----- Confluence -----
    # URL de l'instance (sans slash final) + espace de la base de connaissances.
    BaseUrl            = 'https://confluence.apps.eul.sncf.fr'
    SpaceKey           = 'KM'
    # Page d'atterrissage (sert aussi à déclencher le SSO au démarrage).
    HomePath           = '/spaces/KM/overview'
    # Domaines autorisés pour le SSO Windows intégré (Kerberos/Negotiate).
    AuthAllowlist      = '*.sncf.fr'

    # ----- Recherche -----
    # Types de contenu remontés par défaut (filtre « Tout »).
    ContentTypes       = @('page', 'blogpost', 'attachment')
    PageSize           = 20      # résultats par page (« Afficher plus » charge la suite)
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

    # ----- Disposition -----
    # 'top' : barre fine en haut + panneau déroulant ; 'left' / 'right' : barre latérale.
    Mode               = 'top'
    BarHeight          = 48      # hauteur de la barre en mode 'top' (px logiques)
    Thickness          = 440     # largeur de la barre en mode latéral
    PanelWidth         = 800     # largeur du panneau déroulant (mode 'top')
    PanelHeight        = 620     # hauteur du panneau déroulant (mode 'top')
    # Raccourci global pour ouvrir la recherche depuis n'importe où.
    Hotkey             = 'Ctrl+Alt+K'

    # ----- Mise à jour automatique (GitHub) -----
    # Dépôt PUBLIC 'propriétaire/nom' : lecture anonyme, AUCUN jeton stocké.
    # latest.json (branche UpdateBranch) annonce la version + l'URL du zip (asset de
    # la release) + son empreinte SHA-256 (vérifiée avant installation).
    GitHubRepo             = 'Lixirian/Biblio-Tech-Widget'
    UpdateBranch           = 'main'
    # Contrôle ~10 s après le lancement, puis à cette cadence (secondes, min. 60).
    UpdateCheckIntervalSec = 1800
}
