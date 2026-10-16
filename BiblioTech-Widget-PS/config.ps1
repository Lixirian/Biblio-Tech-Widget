# ============================================================================
#  Configuration centrale du Biblio-Tech Widget (PowerShell + WPF + WebView2).
#  Un seul fichier à éditer pour changer d'instance Confluence, d'espace ou de
#  dépôt de mise à jour.
# ============================================================================

$Config = @{
    # Version de l'application. À INCRÉMENTER à chaque publication (build-release.ps1
    # lit cette valeur pour nommer le zip, la release GitHub et latest.json).
    Version            = '1.1.3'

    # ----- Confluence -----
    # URL de l'instance (sans slash final).
    BaseUrl            = 'https://confluence.apps.eul.sncf.fr'
    # Vide = recherche dans tout Biblio-Tech. Une clé d'espace (ex. 'KM') ajoute un
    # filtre « Espace <clé> » et limite l'accueil « Mis à jour récemment » à cet espace.
    SpaceKey           = ''
    # Page d'accueil Biblio-Tech : atterrissage du SSO au démarrage et lien
    # « Ouvrir Biblio-Tech dans le navigateur ».
    HomePath           = '/'
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

    # ----- Fenêtre -----
    # Taille au premier lancement (ensuite : taille/position mémorisées dans state.json).
    WindowWidth        = 980
    WindowHeight       = 740
    # Raccourci global pour afficher la fenêtre, recherche prête à la saisie.
    Hotkey             = 'Ctrl+Alt+K'

    # ----- Agent Microsoft 365 Copilot (utilisateurs licenciés) -----
    # Lien de l'agent « Biblio-Tech » une fois publié par l'admin M365 (voir
    # copilot-agent\LISEZMOI-DSI.md). Vide = bouton masqué ; les utilisateurs sans
    # licence utilisent l'assistant local (lib\BtAssist.ps1), toujours actif.
    CopilotAgentUrl    = ''

    # ----- Mise à jour automatique (GitHub) -----
    # Dépôt PUBLIC 'propriétaire/nom' : lecture anonyme, AUCUN jeton stocké.
    # latest.json (branche UpdateBranch) annonce la version + l'URL du zip (asset de
    # la release) + son empreinte SHA-256 (vérifiée avant installation).
    GitHubRepo             = 'Lixirian/Biblio-Tech-Widget'
    UpdateBranch           = 'main'
    # Contrôle ~10 s après le lancement, puis à cette cadence (secondes, min. 60).
    UpdateCheckIntervalSec = 1800
}
