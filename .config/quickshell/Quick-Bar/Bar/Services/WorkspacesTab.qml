import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"

// WorkspacesTab — overview des workspaces 1..10 pour le TouchPanel (Xeneon),
// inspiré de ~/.config/quickshell/overview mais pensé tactile :
//   · double-tap tuile → affiche ce workspace sur son écran
//   · tap fenêtre     → focus la fenêtre
//   · glisser fenêtre → la déplace (silencieusement) vers la tuile lâchée
//   · appui long      → vue agrandie de la fenêtre (croix pour sortir)
//   · bouton ×        → ferme la fenêtre
// Après chaque action le focus revient au Xeneon (sinon les taps 1 doigt
// ne cliquent plus, cf. TouchPanel). Aperçus live via ScreencopyView.
// Hyprland en config Lua → actions via `hyprctl eval` + hl.dsp (un seul eval).
Item {
    id: root

    readonly property int rows: 2
    readonly property int cols: 5
    readonly property real gap: 14

    property var clients: []
    property var monitors: []

    // Vue agrandie (appui long) : fenêtre suivie par adresse → disparaît seule
    // si la fenêtre est fermée entre-temps.
    property string zoomAddr: ""
    readonly property var zoomed: zoomAddr === "" ? null : (clients.find(c => c.address === zoomAddr) || null)

    // ── Données Hyprland (rafraîchies sur événement, avec anti-rafale) ──────────
    function refresh() { clientsProc.running = true; monitorsProc.running = true }
    Component.onCompleted: refresh()
    Timer { id: debounce; interval: 80; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { debounce.restart() }
    }
    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.clients = JSON.parse(text).filter(c => c.workspace.id >= 1 && c.workspace.id <= root.rows * root.cols) }
                catch (e) {}
            }
        }
    }
    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.monitors = JSON.parse(text) } catch (e) {} }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    readonly property string xeneonName: {
        const m = monitors.find(m => ((m.model || "") + (m.description || "")).toUpperCase().indexOf("XENEON") !== -1)
        return m ? m.name : ""
    }
    Process { id: actionProc }
    // Hyprland crée un workspace inexistant sur l'écran FOCALISÉ (= le Xeneon
    // pendant qu'on touche le panneau) → on focalise d'abord l'écran principal
    // pour que déplacements/changements atterrissent dessus, puis on rend le
    // focus au Xeneon. Tout dans un seul eval (cf. piège rafale hyprctl eval).
    function run(lua) {
        if (mainMon && mainMon.name !== xeneonName)
            lua = "hl.dispatch(hl.dsp.focus({ monitor = [[" + mainMon.name + "]] })) " + lua
        if (xeneonName !== "")
            lua += " hl.dispatch(hl.dsp.focus({ monitor = [[" + xeneonName + "]] }))"
        actionProc.command = ["hyprctl", "eval", lua]
        actionProc.running = false
        actionProc.running = true
        GameBreak.extend()
    }
    function focusWorkspace(id) { run("hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))") }
    function focusWindow(addr)  { run("hl.dispatch(hl.dsp.focus({ window = 'address:" + addr + "' }))") }
    function closeWindow(addr)  { run("hl.dispatch(hl.dsp.window.close({ window = 'address:" + addr + "' }))") }
    function moveWindow(addr, id) {
        run("hl.dispatch(hl.dsp.window.move({ workspace = " + id + ", follow = false, window = 'address:" + addr + "' }))")
    }

    // ── Géométrie : tuiles au ratio de l'écran principal (zone utile) ───────────
    function usable(m) {
        const r = m.reserved || [0, 0, 0, 0]
        const w = m.width / m.scale, h = m.height / m.scale
        return (m.transform % 2 === 1)
            ? { w: h - r[0] - r[2], h: w - r[1] - r[3] }
            : { w: w - r[0] - r[2], h: h - r[1] - r[3] }
    }
    readonly property var mainMon: monitors.find(m => m.name !== xeneonName) || monitors[0] || null
    readonly property real aspect: mainMon ? usable(mainMon).w / usable(mainMon).h : 16 / 9
    readonly property real tileW: Math.max(1, Math.min((width - (cols - 1) * gap) / cols,
                                                       ((height - (rows - 1) * gap) / rows) * aspect))
    readonly property real tileH: tileW / aspect
    readonly property var activeIds: monitors.map(m => m.activeWorkspace.id)
    // Mode vidéo : currentWall est un .mp4 → vignette statique (cf. TouchPanel).
    readonly property string wallSrc: WallpaperState.videoMode
        ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
        : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")

    // Toplevel Wayland correspondant à une adresse Hyprland (pour l'aperçu live).
    function toplevelFor(addr) {
        const all = ToplevelManager.toplevels.values
        for (let i = 0; i < all.length; i++)
            if ("0x" + all[i].HyprlandToplevel?.address === addr) return all[i]
        return null
    }
    // Tuile (1..N) sous un point du repère `grid`, ou -1.
    function workspaceAt(px, py) {
        const c = Math.floor(px / (tileW + gap)), r = Math.floor(py / (tileH + gap))
        if (c < 0 || c >= cols || r < 0 || r >= rows) return -1
        if (px - c * (tileW + gap) > tileW || py - r * (tileH + gap) > tileH) return -1
        return r * cols + c + 1
    }

    Item {
        id: grid
        width:  root.cols * root.tileW + (root.cols - 1) * root.gap
        height: root.rows * root.tileH + (root.rows - 1) * root.gap
        anchors.centerIn: parent

        property int hoverTarget: -1

        // Tuiles
        Repeater {
            model: root.rows * root.cols
            delegate: ClippingRectangle {
                id: tile
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: root.activeIds.indexOf(wsId) !== -1
                x: (index % root.cols) * (root.tileW + root.gap)
                y: Math.floor(index / root.cols) * (root.tileH + root.gap)
                width: root.tileW; height: root.tileH
                radius: 20
                color: Appearance.colors.color13

                // Fond d'écran courant (même texture partagée par les 10 tuiles).
                Image {
                    anchors.fill: parent
                    source: root.wallSrc
                    sourceSize.width: 640
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Voile : plus sombre au repos, teinte accent quand on vise la tuile.
                Rectangle {
                    anchors.fill: parent
                    color: grid.hoverTarget === tile.wsId
                        ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.35)
                        : ColorUtils.applyAlpha(Appearance.colors.bg, tile.isActive ? 0.15 : 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: tile.wsId
                    font.family: Appearance.font.family; font.pixelSize: parent.height * 0.45; font.weight: Font.Bold
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: tile.radius; color: "transparent"
                    border.width: tile.isActive ? 3 : 1
                    border.color: tile.isActive ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                }
                // Double-tap → passe sur ce workspace (simple tap ignoré : évite
                // les changements accidentels en manipulant les fenêtres).
                MouseArea { anchors.fill: parent; onDoubleClicked: root.focusWorkspace(tile.wsId) }
            }
        }

        // Fenêtres (flottantes au-dessus des tuilées, puis ordre de focus)
        Repeater {
            // objectProp → délégués réutilisés par adresse (pas de recréation des
            // aperçus live à chaque événement Hyprland).
            model: ScriptModel {
                objectProp: "address"
                values: root.clients.slice().sort((a, b) =>
                    (a.floating !== b.floating) ? (a.floating ? 1 : -1) : (b.focusHistoryID - a.focusHistoryID))
            }
            delegate: Item {
                id: win
                required property var modelData
                required property int index
                readonly property var mon: root.monitors.find(m => m.id === modelData.monitor) || null
                readonly property var area: mon ? root.usable(mon) : { w: 1920, h: 1080 }
                readonly property real s: Math.min(root.tileW / area.w, root.tileH / area.h)
                readonly property int slot: modelData.workspace.id - 1
                readonly property real baseX: (slot % root.cols) * (root.tileW + root.gap)
                    + Math.max(0, (modelData.at[0] - (mon?.x ?? 0) - (mon?.reserved?.[0] ?? 0)) * s)
                readonly property real baseY: Math.floor(slot / root.cols) * (root.tileH + root.gap)
                    + Math.max(0, (modelData.at[1] - (mon?.y ?? 0) - (mon?.reserved?.[1] ?? 0)) * s)
                property real dx: 0
                property real dy: 0

                x: baseX + dx; y: baseY + dy
                width:  Math.min(modelData.size[0] * s, root.tileW)
                height: Math.min(modelData.size[1] * s, root.tileH)
                z: touchArea.dragging ? 1000 : 1 + index
                scale: touchArea.dragging ? 1.05 : 1
                Behavior on scale { NumberAnimation { duration: 100 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 20; clip: true
                    color: ColorUtils.applyAlpha(Appearance.colors.surface, 0.85)
                    border.width: 2
                    border.color: touchArea.pressed ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.2)

                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: root.visible ? root.toplevelFor(win.modelData.address) : null
                        live: true
                    }
                    Image {
                        anchors.centerIn: parent
                        readonly property real sz: Math.min(parent.width, parent.height) * 0.35
                        width: sz; height: sz; sourceSize: Qt.size(sz, sz)
                        source: Quickshell.iconPath(DesktopEntries.heuristicLookup(win.modelData.class)?.icon
                                                    ?? win.modelData.class, "application-x-executable")
                        opacity: 0.9
                    }
                }

                MouseArea {
                    id: touchArea
                    preventStealing: true
                    anchors.fill: parent
                    property point start
                    property bool dragging: false
                    property bool held: false
                    pressAndHoldInterval: 450
                    onPressed: (m) => { start = mapToItem(grid, m.x, m.y); dragging = false; held = false }
                    // Appui long sans bouger → vue agrandie de la fenêtre.
                    onPressAndHold: if (!dragging) { held = true; root.zoomAddr = win.modelData.address; GameBreak.extend() }
                    onPositionChanged: (m) => {
                        const p = mapToItem(grid, m.x, m.y)
                        win.dx += p.x - start.x; win.dy += p.y - start.y
                        start = p
                        if (Math.abs(win.dx) + Math.abs(win.dy) > 12) dragging = true
                        if (dragging) grid.hoverTarget = root.workspaceAt(win.x + win.width / 2, win.y + win.height / 2)
                    }
                    onReleased: {
                        const target = grid.hoverTarget
                        if (held) { held = false; win.dx = 0; win.dy = 0; return }
                        if (dragging && target !== -1 && target !== win.modelData.workspace.id)
                            root.moveWindow(win.modelData.address, target)
                        else if (!dragging)
                            root.focusWindow(win.modelData.address)
                        win.dx = 0; win.dy = 0; dragging = false; grid.hoverTarget = -1
                    }
                }

                // Fermer (coin haut-droit, taille doigt)
                Rectangle {
                    visible: win.width > 60 && !touchArea.dragging
                    anchors { top: parent.top; right: parent.right; margins: 4 }
                    width: 34; height: 34; radius: 17
                    color: ColorUtils.applyAlpha(Appearance.colors.red, 0.85)
                    Text {
                        anchors.centerIn: parent; text: "󰅖"
                        font.family: Appearance.font.family; font.pixelSize: 18
                        color: Appearance.colors.bg
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.closeWindow(win.modelData.address) }
                }
            }
        }
    }

    // ══ Vue agrandie (appui long sur une fenêtre) ══
    // Aperçu live au ratio de la fenêtre ; croix ou tap à côté = sortir.
    Rectangle {
        anchors.fill: parent
        visible: root.zoomed !== null
        z: 100
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.8)
        MouseArea { anchors.fill: parent; onClicked: root.zoomAddr = "" }

        ClippingRectangle {
            id: zoomBox
            readonly property real ratio: root.zoomed ? root.zoomed.size[0] / Math.max(1, root.zoomed.size[1]) : 16 / 9
            readonly property real maxW: parent.width * 0.92
            readonly property real maxH: parent.height * 0.86
            width:  Math.min(maxW, maxH * ratio)
            height: width / ratio
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 20
            radius: 16
            color: Appearance.colors.surface
            border.width: 3; border.color: Appearance.colors.accent
            MouseArea { anchors.fill: parent }   // absorbe (ne ferme pas)

            ScreencopyView {
                anchors.fill: parent
                captureSource: root.zoomed ? root.toplevelFor(root.zoomed.address) : null
                live: true
            }
        }

        // Titre au-dessus de l'aperçu
        Text {
            anchors.bottom: zoomBox.top; anchors.bottomMargin: 10
            anchors.left: zoomBox.left; anchors.right: closeZoom.left; anchors.rightMargin: 16
            text: root.zoomed ? root.zoomed.title + "  ·  ws " + root.zoomed.workspace.id : ""
            font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Medium
            color: Appearance.colors.fg
            elide: Text.ElideRight
        }

        // Croix (sortir de la vue agrandie)
        Rectangle {
            id: closeZoom
            anchors.bottom: zoomBox.top; anchors.bottomMargin: 6
            anchors.right: zoomBox.right
            width: 56; height: 56; radius: 28
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.9)
            border.width: 2; border.color: Appearance.colors.accent
            Text {
                anchors.centerIn: parent; text: "󰅖"
                font.family: Appearance.font.family; font.pixelSize: 26
                color: Appearance.colors.fg
            }
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.zoomAddr = "" }
        }
    }
}
