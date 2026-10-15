# ============================================================================
#  Persistance de l'état utilisateur (state.json dans %LOCALAPPDATA%) :
#  préférences d'affichage, filtres, historique de recherche, pages épinglées.
#  Aucun identifiant ni jeton n'est jamais stocké ici.
# ============================================================================

function New-BtState {
    param([string]$Path)
    $st = @{
        Path       = $Path
        Version    = ''
        Bounds     = ''           # taille/position de la fenêtre 'gauche,haut,largeur,hauteur'
        Maximized  = $false
        Scope      = 'all'        # 'all' (tout Biblio-Tech) | 'space' (espace Config.SpaceKey, si configuré)
        Type       = 'all'        # 'all' | 'page' | 'blogpost' | 'attachment'
        Sort       = 'relevance'  # 'relevance' | 'recent'
        ReaderMode = $true        # mode lecture (chrome Confluence masqué) dans le lecteur
        CopilotLicensed = $false  # l'utilisateur a une licence M365 Copilot -> bouton « Demander à Copilot »
        History    = @()
        Pins       = @()
    }
    if (Test-Path -LiteralPath $Path) {
        try {
            $j = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @('Version', 'Bounds', 'Scope', 'Type', 'Sort')) {
                if ($j.PSObject.Properties.Name -contains $k -and $j.$k) { $st[$k] = [string]$j.$k }
            }
            if ($j.PSObject.Properties.Name -contains 'ReaderMode') { $st.ReaderMode = [bool]$j.ReaderMode }
            if ($j.PSObject.Properties.Name -contains 'Maximized') { $st.Maximized = [bool]$j.Maximized }
            if ($j.PSObject.Properties.Name -contains 'CopilotLicensed') { $st.CopilotLicensed = [bool]$j.CopilotLicensed }
            if ($j.History) { $st.History = @($j.History | ForEach-Object { [string]$_ } | Where-Object { $_ }) }
            if ($j.Pins) {
                $st.Pins = @($j.Pins | ForEach-Object {
                    @{ id = [string]$_.id; title = [string]$_.title; url = [string]$_.url; space = [string]$_.space; type = [string]$_.type }
                } | Where-Object { $_.url })
            }
        } catch { Write-BtLog "[STATE] state.json illisible, état par défaut ($($_.Exception.Message))" }
    }
    return $st
}

# Écriture atomique (fichier temporaire puis remplacement) : un arrêt brutal ne
# laisse jamais un state.json tronqué.
function Save-BtState {
    param($State)
    try {
        $o = [ordered]@{}
        foreach ($k in @('Version', 'Bounds', 'Maximized', 'Scope', 'Type', 'Sort', 'ReaderMode', 'CopilotLicensed', 'History', 'Pins')) { $o[$k] = $State[$k] }
        $json = $o | ConvertTo-Json -Depth 5
        $tmp = $State.Path + '.tmp'
        [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
        Move-Item -LiteralPath $tmp -Destination $State.Path -Force
    } catch { Write-BtLog "[STATE] Sauvegarde KO : $($_.Exception.Message)" }
}

# Ajoute une recherche en tête de l'historique (sans doublon, insensible à la casse).
function Add-BtHistory {
    param($State, [string]$Query, [int]$Max = 15)
    $q = ([string]$Query).Trim()
    if (-not $q) { return }
    $rest = @($State.History | Where-Object { $_ -and ($_.ToLowerInvariant() -ne $q.ToLowerInvariant()) })
    $State.History = @(@($q) + $rest | Select-Object -First $Max)
    Save-BtState $State
}

function Test-BtPinned {
    param($State, $Item)
    $u = [string]$Item.url
    return [bool](@($State.Pins | Where-Object { $_.url -eq $u }).Count)
}

# Épingle / désépingle un résultat. Renvoie $true si l'élément est désormais épinglé.
function Switch-BtPin {
    param($State, $Item)
    $u = [string]$Item.url
    if (-not $u) { return $false }
    if (Test-BtPinned $State $Item) {
        $State.Pins = @($State.Pins | Where-Object { $_.url -ne $u })
        $now = $false
    } else {
        $plain = Get-BtPlainText ([string]$Item.title)
        $State.Pins = @(@{ id = [string]$Item.id; title = $plain; url = $u; space = [string]$Item.space; type = [string]$Item.type }) + @($State.Pins)
        $now = $true
    }
    Save-BtState $State
    return $now
}

# Retire les marqueurs de surlignage (\u0001 / \u0002) d'un texte.
function Get-BtPlainText {
    param([string]$Text)
    return ([string]$Text -replace "[\u0001\u0002]", '')
}
