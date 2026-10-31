pragma Singleton
import QtQuick

QtObject {
    // ── État d'ouverture par popup ─────────────────────────────────────────
    property bool audioOpen:         false
    property bool networkOpen:       false
    property bool batteryOpen:       false
    property bool notificationsOpen: false
    property bool archMenuOpen:      false
    property bool dashboardOpen:     false
    property bool wallpaperOpen:     false   // sélecteur de fond SUPER+W (carrousel)
    property string wallKind:        "image" // ce qu'il montre à l'ouverture : image · video
    property bool wallCinemaOpen:    false   // sélecteur de fond ALT+W (Cinéma)
    property string cinemaKind:      "image"
    property bool notifCenterOpen:   false   // centre de notifications (SUPER+MAJ+N)
    property bool altTabWanted:      false   // ALT+Tab demandé avant la création du panneau
    property bool overviewWanted:    false   // vue d'ensemble demandée (SUPER+A) avant sa création
    property string menuRequest:     ""      // demande de menu (qbmenu) arrivée avant la création du menu
    property bool sessionOpen:       false   // panneau de session CTRL+ALT+P (verrouiller, éteindre…)
    property bool notificationToastOpen: false
    property bool quickOpen:         false
    property bool clipboardOpen:     false
    property bool spotifyOpen:       false   // panneau Spotify (bord droit, SUPER+SHIFT+S)
    property bool settingsOpen:      false
    property bool eqCenterOpen:      false
    property bool touchHidden:       false   // fenêtre envoyée sur le Xeneon (services/XeneonSend.qml) : TouchPanel effacé   // centre audio flottant (clic droit volume / micro de la barre)   // fenêtre Réglages (tuile Config, SUPER+F1)
    property string settingsPage:    ""      // page à ouvrir dans les Réglages ("" = dernière)
    property string touchPage:       ""      // onglet à afficher sur le panneau tactile (demande ponctuelle)
    property string settingsHint:    ""      // sous-partie de la page à ouvrir (ex. "stats" dans Modules)

    // ── Dashboard — largeur de contenu par page (px) ───────────────────────
    property int dashboardPageWidth: 900

    // ── Network popup — page courante (clé string) ─────────────────────────
    property string networkPage: ""

    // ── État hover des déclencheurs ────────────────────────────────────────
    property bool archMenuTriggerHovered:      false
    property bool audioTriggerHovered:         false
    property bool networkTriggerHovered:       false
    property bool batteryTriggerHovered:       false
    property bool notificationsTriggerHovered: false
    property bool wallpaperTriggerHovered:     false
    property bool quickTriggerHovered:         false

    // ── Réglages universels de comportement ────────────────────────────────
    property int slideDuration:   320
    property int hoverCloseDelay: 320 + 200

    // ── Confirm dialog ──────────────────────────────────────────────────────
    property bool   confirmOpen:    false
    property string confirmTitle:   ""
    property string confirmMessage: ""
    property string confirmLabel:   "Confirm"
    property string confirmAction:  ""
    property string confirmGfxMode: ""
    property bool   confirmRunning: false

    function showConfirm(title, message, label, action, gfxMode) {
        confirmTitle   = title
        confirmMessage = message
        confirmLabel   = label
        confirmAction  = action
        confirmGfxMode = gfxMode ?? ""
        confirmOpen    = true
    }

    function cancelConfirm() {
        confirmOpen   = false
        confirmAction = ""
        confirmGfxMode = ""
    }

    // ── État global ─────────────────────────────────────────────────────────
    readonly property bool anyOpen: audioOpen || networkOpen || batteryOpen
                                    || notificationsOpen || archMenuOpen
                                    || dashboardOpen || wallpaperOpen || wallCinemaOpen || sessionOpen || quickOpen
                                    || clipboardOpen || spotifyOpen || eqCenterOpen

    function closeAll() {
        spotifyOpen       = false
        // les Réglages restent ouverts : on les ferme soi-même (croix, Échap, SUPER+F1)
        audioOpen         = false
        networkOpen       = false
        batteryOpen       = false
        notificationsOpen = false
        notifCenterOpen   = false
        archMenuOpen      = false
        dashboardOpen     = false
        wallpaperOpen     = false
        wallCinemaOpen    = false
        sessionOpen       = false
        quickOpen         = false
        clipboardOpen     = false
        eqCenterOpen      = false
    }
}
