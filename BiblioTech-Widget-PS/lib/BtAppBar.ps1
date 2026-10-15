# ============================================================================
#  Reservation d'espace ecran via l'API AppBar du shell Windows (comme la barre
#  des taches) : les fenetres maximisees s'arretent au bord du widget au lieu de
#  passer dessous. Supporte les bords haut / gauche / droite.
#
#  Le retour d'ABM_NEW est verifie (un echec d'enregistrement n'est plus pris
#  pour un succes) et les prototypes sont declares (UINT_PTR sur x64).
# ============================================================================

if (-not ([System.Management.Automation.PSTypeName]'BiblioTech.AppBar').Type) {
    Add-Type -Namespace 'BiblioTech' -Name 'AppBar' -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct RECT { public int left, top, right, bottom; }

[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct APPBARDATA {
    public uint cbSize;
    public System.IntPtr hWnd;
    public uint uCallbackMessage;
    public uint uEdge;
    public RECT rc;
    public System.IntPtr lParam;
}

[System.Runtime.InteropServices.DllImport("shell32.dll")]
public static extern System.IntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);

const uint ABM_NEW = 0, ABM_REMOVE = 1, ABM_QUERYPOS = 2, ABM_SETPOS = 3;
public const int ABE_LEFT = 0, ABE_TOP = 1, ABE_RIGHT = 2;

static bool _registered = false;

public static bool Register(System.IntPtr hwnd, uint callbackMessage) {
    APPBARDATA abd = new APPBARDATA();
    abd.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(abd);
    abd.hWnd = hwnd;
    abd.uCallbackMessage = callbackMessage;
    System.IntPtr r = SHAppBarMessage(ABM_NEW, ref abd);
    _registered = (r != System.IntPtr.Zero);
    return _registered;
}

// Reserve une bande sur le bord donne ; rc = rectangle desire (pixels physiques).
// Retourne le rectangle reellement accorde par le shell (pixels physiques).
public static int[] Reserve(System.IntPtr hwnd, int edge, int left, int top, int right, int bottom, int thickness) {
    if (!_registered) return null;
    APPBARDATA abd = new APPBARDATA();
    abd.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(abd);
    abd.hWnd = hwnd;
    abd.uEdge = (uint)edge;
    abd.rc.left = left; abd.rc.top = top; abd.rc.right = right; abd.rc.bottom = bottom;

    SHAppBarMessage(ABM_QUERYPOS, ref abd);
    // Le shell peut decaler le bord (autres appbars/barre des taches) :
    // on re-fixe l'epaisseur le long du bord apres QUERYPOS.
    if (edge == ABE_TOP)        abd.rc.bottom = abd.rc.top + thickness;
    else if (edge == ABE_LEFT)  abd.rc.right  = abd.rc.left + thickness;
    else if (edge == ABE_RIGHT) abd.rc.left   = abd.rc.right - thickness;
    SHAppBarMessage(ABM_SETPOS, ref abd);

    return new int[] { abd.rc.left, abd.rc.top, abd.rc.right, abd.rc.bottom };
}

public static void Remove(System.IntPtr hwnd) {
    if (!_registered) return;
    APPBARDATA abd = new APPBARDATA();
    abd.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(abd);
    abd.hWnd = hwnd;
    SHAppBarMessage(ABM_REMOVE, ref abd);
    _registered = false;
}
'@
}

$script:BtAppBarRegistered = $false
# HWND de la fenetre actuellement enregistree comme AppBar. Sert a IGNORER un Remove
# venant d'une AUTRE fenetre : lors d'un changement de position (Set-BtMode), la
# NOUVELLE fenetre s'enregistre AVANT que l'ancienne se ferme ; la fermeture de
# l'ancienne appelle Remove avec SON handle. Sans ce garde, le flag global tombait a
# $false alors que la nouvelle fenetre restait AppBar cote OS -> le re-ancrage tentait
# un ABM_NEW sur une fenetre deja enregistree -> echec -> bascule en "Repli" (plus
# aucune reservation, les fenetres passent sous la barre). Cf. Set-BtMode.
$script:BtAppBarHwnd = [System.IntPtr]::Zero

function Register-BtAppBar {
    param([IntPtr]$Hwnd)
    try {
        $ok = [BiblioTech.AppBar]::Register($Hwnd, 0)
        $script:BtAppBarRegistered = $ok
        if ($ok) { $script:BtAppBarHwnd = $Hwnd }
        else { Write-BtLog "[APPBAR] ABM_NEW a echoue : repli sur positionnement simple." }
        return $ok
    } catch {
        Write-BtLog "[APPBAR] Indisponible : $($_.Exception.Message)"
        return $false
    }
}

# Reserve une bande. $Edge = 'top' | 'left' | 'right'. Rectangles en pixels
# physiques. Retourne le rectangle accorde (physique) ou $null.
function Reserve-BtAppBar {
    param([IntPtr]$Hwnd, [string]$Edge, [int]$Left, [int]$Top, [int]$Right, [int]$Bottom, [int]$Thickness)
    if (-not $script:BtAppBarRegistered) { return $null }
    $edgeId = switch ($Edge) {
        'top'   { [BiblioTech.AppBar]::ABE_TOP }
        'left'  { [BiblioTech.AppBar]::ABE_LEFT }
        'right' { [BiblioTech.AppBar]::ABE_RIGHT }
        default { [BiblioTech.AppBar]::ABE_TOP }
    }
    try {
        $r = [BiblioTech.AppBar]::Reserve($Hwnd, $edgeId, $Left, $Top, $Right, $Bottom, $Thickness)
        if ($r) { Write-BtLog "[APPBAR] Bande reservee ($Edge) : $($r -join ',')" }
        return $r
    } catch {
        Write-BtLog "[APPBAR] Echec de la reservation : $($_.Exception.Message)"
        return $null
    }
}

function Remove-BtAppBar {
    param([IntPtr]$Hwnd)
    if (-not $script:BtAppBarRegistered) { return }
    # Ne liberer QUE si le Remove concerne la fenetre actuellement enregistree.
    # Un Remove venant d'une AUTRE fenetre (ancienne fenetre fermee apres un
    # changement de position) est ignore : sinon on desynchronise le flag global de
    # l'etat OS et le re-ancrage suivant echoue (ABM_NEW sur une fenetre deja AppBar
    # -> "Repli"). Le handle 0 (etat indetermine) reste traite par securite.
    if ($script:BtAppBarHwnd -ne [System.IntPtr]::Zero -and $Hwnd -ne $script:BtAppBarHwnd) {
        Write-BtLog "[APPBAR] Remove ignore (handle d'une autre fenetre)."
        return
    }
    try { [BiblioTech.AppBar]::Remove($Hwnd) } catch { }
    $script:BtAppBarRegistered = $false
    $script:BtAppBarHwnd = [System.IntPtr]::Zero
    Write-BtLog "[APPBAR] Bande liberee."
}
