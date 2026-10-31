//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Tous les modules partagés sont importés ici : Quickshell n'enregistre un module qu'une fois
// importé par un fichier déjà chargé ; sans ça, une page chargée plus tard (Grid, Game…)
// échoue avec « module … is not installed ».
import qs.bar
import qs.components
import qs.components.stats
import qs.core
import qs.core.functions
import qs.services
import qs.services.system
import qs.panels
import qs.pages.eq
import qs.wallpaper


import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root
    Wallpaper {}
    LockScreen {}   // toujours chargé (léger) : les surfaces ne sont créées que verrouillé
    // un singleton n'existe qu'une fois lu : Batteries doit tourner dès le lancement pour notifier
    // les connexions de périphériques même dashboard fermé
    readonly property bool batteriesAlive: Batteries.armed || true
    readonly property bool xeneonAlive: XeneonSend.sent !== null          // idem : SUPER+O (IPC xeneon)
    readonly property bool islandAlive: Island.enabled || Shots.hovered    // idem : île dynamique, captures
    TouchPanel {}
    GameBreakBar {}
    Bar {}
    CalendarWindow {}
    EqPopup {}
    SysTrayPopup {}
    MediaPlayerPopup {}
    LazyLoader { id: dashboardL; property bool alive: false; active: Popups.dashboardOpen || alive
        Dashboard { onWindowVisibleChanged: Qt.callLater(() => dashboardL.alive = windowVisible) } }
    LazyLoader { id: spotifyPanelL; property bool alive: false; active: Popups.spotifyOpen || alive
        SpotifyPanel { onWindowVisibleChanged: Qt.callLater(() => spotifyPanelL.alive = windowVisible) } }
    // île dynamique (services/Island.qml) et vignette de capture (services/Shots.qml) : créées à la demande
    LazyLoader { active: Island.current !== null; DynamicIsland {} }
    LazyLoader { id: shotL; property bool alive: false; active: Shots.latest !== "" || alive; ShotThumb {} }
    Connections { target: Shots; function onLatestChanged() { if (Shots.latest !== "") { shotHide.stop(); shotL.alive = true } else shotHide.restart() } }
    Timer { id: shotHide; interval: 700; onTriggered: shotL.alive = false }   // le temps de glisser hors de l'écran
    LazyLoader { id: eqCenterL; property bool alive: false; active: Popups.eqCenterOpen || alive
        EqCenter { onWindowVisibleChanged: Qt.callLater(() => eqCenterL.alive = windowVisible) } }
    IpcHandler {
        target: "xeneon"         // SUPER+O : fenêtre active → plein écran sur le Xeneon, puis retour
        function toggle() { XeneonSend.toggle() }
    }
    IpcHandler {
        target: "audio"          // centre audio flottant (aussi : clic droit sur le volume / le micro de la barre)
        function center() { const o = !Popups.eqCenterOpen; Popups.closeAll(); Popups.eqCenterOpen = o }
    }
    LazyLoader { id: settingsPanelL; property bool alive: false; active: Popups.settingsOpen || alive
        SettingsPanel { onWindowVisibleChanged: Qt.callLater(() => settingsPanelL.alive = windowVisible) } }
    // ── panneaux créés seulement quand ils sont ouverts (aucune RAM fermés) ──
    LazyLoader { id: wpL; property bool alive: false; active: Popups.wallpaperOpen || alive
        WallpaperPicker { onWindowVisibleChanged: Qt.callLater(() => wpL.alive = windowVisible) } }
    IpcHandler {
        target: "wallcinema"
        function toggle() { if (!Popups.wallCinemaOpen) Popups.cinemaKind = "image"; Popups.wallCinemaOpen = !Popups.wallCinemaOpen }
        function videos() { Popups.cinemaKind = "video"; Popups.wallCinemaOpen = true }
    }
    IpcHandler {
        target: "minimize"      // services/Minimize.qml (remplace niflveil)
        function minimize()    { Minimize.minimize() }
        function restoreLast() { Minimize.restoreLast() }
        function restoreAll()  { Minimize.restoreAll() }
    }
    IpcHandler {
        target: "session"
        function toggle() { Popups.sessionOpen = !Popups.sessionOpen }
        function open()   { Popups.sessionOpen = true }
    }
    IpcHandler {
        target: "settings"
        function toggle() { if (!Popups.settingsOpen) Popups.closeAll(); Popups.settingsOpen = !Popups.settingsOpen }
        function open(p: string) { Popups.closeAll(); Popups.settingsPage = p; Popups.settingsOpen = true }
    }
    IpcHandler {
        target: "spotify"
        function toggle() { if (!Popups.spotifyOpen) Popups.closeAll(); Popups.spotifyOpen = !Popups.spotifyOpen }
    }
    IpcHandler {
        target: "dashboard-home"
        function toggle() {
            const d = dashboardL.item
            if (Popups.anyOpen && !Popups.dashboardOpen) { Popups.closeAll(); Popups.dashboardOpen = true; if (d) d.page = d.homeKey }
            else if (Popups.dashboardOpen && d && d.page != d.homeKey) d.page = d.homeKey
            else if (Popups.dashboardOpen) Popups.dashboardOpen = false
            else { Popups.dashboardOpen = true; if (d) d.page = d.homeKey }
        }
        // ouvre directement un onglet : qs ipc call dashboard-home open battery
        function open(p: string) {
            if (!Popups.dashboardOpen) { Popups.closeAll(); Popups.dashboardOpen = true }
            Qt.callLater(() => { if (dashboardL.item) dashboardL.item.page = p })
        }
    }
    IpcHandler {
        target: "wallpicker"
        function toggle() { if (!Popups.wallpaperOpen) Popups.wallKind = "image"; Popups.wallpaperOpen = !Popups.wallpaperOpen }
        function videos() { Popups.wallKind = "video"; Popups.wallpaperOpen = true }
        function random() { WallpaperState.randomWall() }
    }
    LazyLoader { id: wallpaperCinemaL; property bool alive: false; active: Popups.wallCinemaOpen || alive
        WallpaperCinema { onWindowVisibleChanged: Qt.callLater(() => wallpaperCinemaL.alive = windowVisible) } }
    LazyLoader { id: sessionPanelL; property bool alive: false; active: Popups.sessionOpen || alive
        SessionPanel { onWindowVisibleChanged: Qt.callLater(() => sessionPanelL.alive = windowVisible) } }
    // notifications : toasts (créés seulement quand il y en a) et centre (à l'ouverture)
    LazyLoader { id: toastsL; property bool alive: false; active: NotificationService.toasts.length > 0 || alive
        NotifToasts { onBusyChanged: Qt.callLater(() => toastsL.alive = busy) } }
    LazyLoader { id: notifCenterL; property bool alive: false; active: Popups.notifCenterOpen || alive
        NotifCenter { onWindowVisibleChanged: Qt.callLater(() => notifCenterL.alive = windowVisible) } }
    IpcHandler {
        target: "notifications"
        function toggle() { if (!Popups.notifCenterOpen) Popups.closeAll(); Popups.notifCenterOpen = !Popups.notifCenterOpen }
        function clear()  { NotificationService.dismissAll() }
        function dnd()    { ShellState.dnd = !ShellState.dnd }
    }
    LazyLoader { id: altTabL; property bool alive: false; active: Popups.altTabWanted || alive
        onAliveChanged: if (alive) Popups.altTabWanted = false
        AltTab { readonly property bool busy: shown || loading; onBusyChanged: Qt.callLater(() => altTabL.alive = busy) } }
    IpcHandler {
        target: "updates"
        function upgrade() { Updates.upgrade() }
        function refresh() { Updates.refresh() }
        function menu()    { Updates.openMenu() }
    }
    IpcHandler {
        target: "alttab"
        function next()   { if (altTabL.item) altTabL.item.step(1);  else Popups.altTabWanted = true }
        function prev()   { if (altTabL.item) altTabL.item.step(-1); else { Popups.altTabWanted = true } }
        function commit() { if (altTabL.item) altTabL.item.commit() }
        function cancel() { if (altTabL.item) altTabL.item.cancel() }
    }
    LazyLoader { id: overviewL; property bool alive: false; active: Popups.overviewWanted || alive
        onAliveChanged: if (alive) Popups.overviewWanted = false     // la demande est prise en charge
        Overview { readonly property bool busy: shown || pending; onBusyChanged: Qt.callLater(() => overviewL.alive = busy) } }
    IpcHandler {
        target: "overview"
        function toggle() { if (overviewL.item) overviewL.item.toggle(); else Popups.overviewWanted = true }
        function open()   { if (overviewL.item) overviewL.item.open();   else Popups.overviewWanted = true }
    }
    // Le menu (Super, SUPER+MAJ+G…) reste chargé : créé 4 s après le démarrage, avec la liste des
    // applications, pour que même la 1re ouverture soit instantanée (sinon ~2 s)
    property bool menuWarm: false
    Timer { interval: 4000; running: true; onTriggered: root.menuWarm = true }
    readonly property int _appsWarm: menuWarm ? DesktopEntries.applications.values.length : 0
    LazyLoader { id: menuL; property bool alive: false; active: root.menuWarm || Popups.menuRequest !== "" || alive
        onAliveChanged: if (alive) Popups.menuRequest = ""             // la demande est prise en charge
        Menu { readonly property bool busy: shown || loading; onBusyChanged: Qt.callLater(() => menuL.alive = busy) } }
    Process { id: menuRun }
    IpcHandler {
        target: "menu"
        function open(path: string) { if (menuL.item) menuL.item.loadPath(path); else Popups.menuRequest = path }
        function close() { if (menuL.item) menuL.item.finish(1, "") }
        // id de la demande affichée ("" si aucune) : qbmenu abandonne si ce n'est plus la sienne
        function current(): string { const m = menuL.item; return m && m.open ? (m.req.id || "") : "" }
        // menus/scripts/<name>.sh ; relancer le même menu le referme
        function run(name: string) {
            const m = menuL.item
            if (m && m.open && m.req.script === name) { m.finish(1, ""); return }
            menuRun.command = ["setsid", "-f", Quickshell.shellDir + "/menus/run.sh", name]
            menuRun.running = false; menuRun.running = true
        }
        function apps() { run("apps") }
    }
    // génère Quick-Bar/hypr/quickbar.lua (raccourcis) et s'assure que hyprland.lua le charge
    readonly property var _keybinds: KeybindService
}
