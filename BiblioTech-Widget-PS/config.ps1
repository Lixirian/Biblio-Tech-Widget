# ============================================================================
#  Configuration centrale du Biblio-Tech Widget (PowerShell + WPF + WebView2).
#  Un seul fichier à éditer pour changer d'instance Confluence, d'espace ou de
#  dépôt de mise à jour.
# ============================================================================

$Config = @{
    # Version de l'application. À INCRÉMENTER à chaque publication (build-release.ps1
    # lit cette valeur pour nommer le zip, la release GitHub et latest.json).
    Version            = '1.1.12'

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
    UpdateCheckIntervalSec = 120
}
