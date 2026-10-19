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
import qs.wallpaper


import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Wallpaper {}
    LockScreen {}   // toujours chargé (léger) : les surfaces ne sont créées que verrouillé
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
    LazyLoader { id: menuL; property bool alive: false; active: Popups.menuRequest !== "" || alive
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
