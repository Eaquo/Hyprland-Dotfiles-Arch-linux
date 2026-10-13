pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// État global du shell.
// WiFi / Bluetooth / DND / Hotspot / Focus / ScreenRecord — écrits par QuickSettings.
//
// Les modes purement UI (barMainOnly, touchPanelOn, touchTabs) sont persistés sur disque
// (user_data/shell_state.json) et restaurés au démarrage / reboot.

QtObject {
    id: root

    property int topBarLWidth: 0
    property int topBarCWidth: 0
    property int topBarRWidth: 0

    property bool focusMode:    false
    property bool dnd:          false
    property bool screenRecord: false
    property bool hotspot:      false
    property bool airplane:     false
    property bool barMainOnly:  false   // barre sur l'écran principal uniquement (vs tous)
    property bool touchPanelOn: false   // panneau widgets plein écran sur le tactile (Xeneon Edge)
    // Onglets du TouchPanel : [{ key, on }] dans l'ordre choisi (bouton config).
    // Vide = ordre/état par défaut du catalogue (TouchPanel.allTabs).
    property var  touchTabs:    []

    // ── Persistance disque (restaurée au reboot) ───────────────────────────────
    readonly property string _path:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/user_data/shell_state.json"

    property bool _loading: false
    // Pas de sauvegarde avant la 1re lecture du fichier : sinon les valeurs par
    // défaut (émises à la création, ex. touchTabs) écrasent l'état au démarrage.
    property bool _ready: false

    function _parse(txt) {
        if (!txt || txt.length === 0) return
        try {
            var d = JSON.parse(txt)
            root._loading = true
            if (d.barMainOnly  !== undefined) root.barMainOnly  = d.barMainOnly
            if (d.touchPanelOn !== undefined) root.touchPanelOn = d.touchPanelOn
            if (Array.isArray(d.touchTabs))   root.touchTabs    = d.touchTabs
            root._loading = false
        } catch (e) { root._loading = false }
    }

    function _save() {
        if (root._loading || !root._ready) return
        var json = JSON.stringify({
            barMainOnly:  root.barMainOnly,
            touchPanelOn: root.touchPanelOn,
            touchTabs:    root.touchTabs
        })
        saveProc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_", json, root._path]
        saveProc.running = false
        saveProc.running = true
    }

    property var _fv: FileView {
        path:         "file://" + root._path
        watchChanges: true
        onFileChanged: reload()
        onLoaded:      { root._parse(text()); root._ready = true }
        onLoadFailed:  root._ready = true      // pas encore de fichier → on peut créer
    }
    property var _saveProc: Process { id: saveProc }

    onBarMainOnlyChanged:  _save()
    onTouchPanelOnChanged: _save()
    onTouchTabsChanged:    _save()

    // WiFi — false quand la radio est coupée OU que le hotspot occupe l'interface
    property bool wifiOn: false

    // VPN
    property bool   vpnActive:     false
    property bool   vpnConnecting: false
    property string vpnName:       ""

    // Bluetooth
    property bool btPowered:   false
    property bool btConnected: false

    // Fournisseur de config (conservé pour compat ; non utilisé dans Quick-Bar)
    property string configProvider: "lua"
}
