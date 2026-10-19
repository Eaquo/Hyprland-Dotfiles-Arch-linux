import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.core.functions

// Overview — vue d'ensemble des espaces de l'écran principal (SUPER+A, `qs ipc call overview toggle`).
// Remplace le plugin scrolloverview : même bandeau vertical (échelle [overview] scale, 0.7),
// mais animé : le bureau rétrécit en carte et les autres espaces glissent autour ; en sortant on
// replonge dans l'espace choisi. Aperçus live (ScreencopyView) des cartes proches.
//   ↑↓ / molette espaces · ←→ fenêtres · Entrée aller · 1-9 sauter · x / clic milieu fermer
//   Maj+↑↓ ou glisser : déplacer la fenêtre · carte « + » = nouvel espace · Échap revenir
// Actions Hyprland : `hyprctl eval` + hl.dsp, un seul eval par action (cf. WorkspacesTab).
PanelWindow {
    id: root

    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }
    color: "transparent"
    visible: shown
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:overview-main"
    WlrLayershell.keyboardFocus: shown && !leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real sc: Number(Config.get("overview.scale", 0.5))
    Behavior on sc { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutCubic } }
    readonly property bool halo: Config.get("overview.halo", true) !== false
    function zoom(d) {
        const v = Math.round(Math.max(0.3, Math.min(0.8, Number(Config.get("overview.scale", 0.5)) + d)) * 100) / 100
        Config.set("overview.scale", v === 0.5 ? null : v)
    }
    function toggleHalo() { Config.set("overview.halo", halo ? false : null) }
    readonly property real gap: Number(Config.get("overview.gap", 100))
    readonly property real cw: width * sc
    readonly property real ch: height * sc

    // ── état ──────────────────────────────────────────────────────────────
    property bool shown: false
    property bool leaving: false
    property bool pending: false
    property real z: 0                   // 0 = plein écran (le bureau), 1 = vue d'ensemble
    readonly property real ez: z < 0.5 ? 4 * z * z * z : 1 - Math.pow(-2 * z + 2, 3) / 2
    property real pos: 0                 // carte au centre (animée)
    property int selWs: 0                // index dans wsList
    property string selWin: ""
    property int startIdx: 0
    property int hoverWs: -1             // carte survolée (mise en avant, un clic = y aller)

    property var clients: []
    property var monitors: []
    property var workspaces: []
    property int _loaded: 0
    readonly property var mon: monitors.find(m => !Config.isTouch(m)) || monitors[0] || null
    readonly property real monW: mon ? (mon.transform % 2 ? mon.height : mon.width) / mon.scale : width
    readonly property real monH: mon ? (mon.transform % 2 ? mon.width : mon.height) / mon.scale : height
    // espaces de l'écran principal + une carte « + » (premier numéro libre)
    readonly property var wsList: {
        if (!mon) return []
        const own = workspaces.filter(w => w.monitorID === mon.id && w.id > 0).map(w => w.id)
        if (own.indexOf(mon.activeWorkspace.id) < 0) own.push(mon.activeWorkspace.id)
        own.sort((a, b) => a - b)
        const used = workspaces.map(w => w.id)
        let free = 1
        while (used.indexOf(free) >= 0 || own.indexOf(free) >= 0) free++
        return own.map(id => ({ id: id, plus: false })).concat([{ id: free, plus: true }])
    }
    function winsOf(id) {
        return clients.filter(c => c.workspace.id === id && c.mapped !== false)
                      .sort((a, b) => (a.floating !== b.floating) ? (a.floating ? 1 : -1) : (a.at[0] - b.at[0]) || (a.at[1] - b.at[1]))
    }
    readonly property var selWins: wsList.length ? winsOf(wsList[selWs].id) : []

    // ── données ───────────────────────────────────────────────────────────
    function refresh() { cProc.running = true; mProc.running = true; wProc.running = true }
    Process { id: cProc; command: ["hyprctl", "clients", "-j"]
              stdout: StdioCollector { onStreamFinished: { try { root.clients = JSON.parse(text) } catch (e) {} root._done() } } }
    Process { id: mProc; command: ["hyprctl", "monitors", "-j"]
              stdout: StdioCollector { onStreamFinished: { try { root.monitors = JSON.parse(text) } catch (e) {} root._done() } } }
    Process { id: wProc; command: ["hyprctl", "workspaces", "-j"]
              stdout: StdioCollector { onStreamFinished: { try { root.workspaces = JSON.parse(text) } catch (e) {} root._done() } } }
    function _done() {
        if (!pending || ++_loaded < 3) return
        pending = false
        startIdx = Math.max(0, wsList.findIndex(w => w.id === mon.activeWorkspace.id))
        selWs = startIdx; pos = startIdx
        const f = clients.filter(c => c.workspace.id === wsList[startIdx].id).sort((a, b) => a.focusHistoryID - b.focusHistoryID)[0]
        selWin = f ? f.address : ""
        z = 0; leaving = false; shown = true
        keys.forceActiveFocus()
        outSeq.stop(); inAnim.restart()
    }
    Timer { id: debounce; interval: 90; onTriggered: if (root.shown && !root.leaving) root.refresh() }
    Connections { target: Hyprland; function onRawEvent(ev) { if (root.shown) debounce.restart() } }

    function open() { if (shown || pending) return; pending = true; _loaded = 0; refresh() }
    function toggle() { if (shown) leave(startIdx, "", false); else open() }
    // créé par un LazyLoader (shell.qml) à l'ouverture, détruit après : aucune RAM fermé. IPC « overview » dans shell.qml.
    // ouvrir AVANT de baisser la demande (sinon le LazyLoader se désactive aussitôt), et en différé
    Component.onCompleted: if (Popups.overviewWanted) open()   // remise à zéro par shell.qml

    // ── actions ───────────────────────────────────────────────────────────
    Process { id: act }
    function run(lua) {
        act.command = ["hyprctl", "eval", "hl.config({ cursor = { no_warps = true } }) " + lua + " hl.config({ cursor = { no_warps = false } })"]
        act.running = false; act.running = true
    }
    function addr(a) { return "'address:" + a + "'" }
    // sortir vers l'espace idx (et la fenêtre a) : on y va tout de suite (caché sous la carte),
    // puis la carte revient au centre et replonge en plein écran
    function leave(idx, a, go) {
        if (leaving || !shown) return
        leaving = true
        selWs = idx
        if (go) {
            const id = wsList[idx].id
            run("hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))" + (a ? " hl.dispatch(hl.dsp.focus({ window = " + addr(a) + " }))" : ""))
        }
        inAnim.stop(); outSeq.restart()
    }
    function closeWin(a) { run("hl.dispatch(hl.dsp.window.close({ window = " + addr(a) + " }))") }
    function moveWin(a, idx) {
        const id = wsList[idx].id
        run("hl.dispatch(hl.dsp.window.move({ workspace = " + id + ", follow = false, window = " + addr(a) + " }))")
    }
    function pickWs(i) {
        i = Math.max(0, Math.min(wsList.length - 1, i))
        selWs = i
        const w = winsOf(wsList[i].id)
        selWin = w.length ? w[0].address : ""
    }
    function stepWin(d) {
        const w = selWins
        if (!w.length) return
        const k = w.findIndex(c => c.address === selWin)
        selWin = w[((k < 0 ? 0 : k + d) + w.length) % w.length].address
    }

    NumberAnimation { id: inAnim; target: root; property: "z"; from: 0; to: 1; duration: Appearance.dur(520) }
    SequentialAnimation {
        id: outSeq
        PauseAnimation { duration: Math.abs(root.pos - root.selWs) > 0.01 ? Appearance.dur(300) : 0 }
        NumberAnimation { target: root; property: "z"; to: 0; duration: Appearance.dur(460) }
        ScriptAction { script: { root.shown = false; root.leaving = false } }
    }
    Behavior on pos { NumberAnimation { duration: Appearance.dur(320); easing.type: Easing.OutCubic } }
    onSelWsChanged: pos = selWs

    // ── clavier ───────────────────────────────────────────────────────────
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            const shift = e.modifiers & Qt.ShiftModifier
            if (e.key === Qt.Key_Escape || (e.key === Qt.Key_A && (e.modifiers & Qt.MetaModifier))) root.leave(root.startIdx, "", false)
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
                const d = e.key === Qt.Key_Up ? -1 : 1
                const t = root.selWs + d
                if (shift && root.selWin && t >= 0 && t < root.wsList.length) { root.moveWin(root.selWin, t); root.selWs = t }
                else root.pickWs(t)
            }
            else if (e.key === Qt.Key_Left)  root.stepWin(-1)
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.stepWin(1)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.leave(root.selWs, root.selWin, true)
            else if ((e.key === Qt.Key_X || e.key === Qt.Key_Delete) && root.selWin) root.dying = root.selWin
            else if (e.key === Qt.Key_H) root.toggleHalo()
            else if (e.key === Qt.Key_Minus) root.zoom(-0.05)
            else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) root.zoom(0.05)
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                const i = root.wsList.findIndex(w => w.id === e.key - Qt.Key_0)
                if (i >= 0) root.pickWs(i)
            }
            e.accepted = true
        }
    }
    property string dying: ""            // fenêtre en train de rétrécir avant fermeture
    onDyingChanged: if (dying) dieT.restart()
    Timer { id: dieT; interval: Appearance.dur(260); onTriggered: { root.closeWin(root.dying); root.stepWin(1); root.dying = "" } }

    function toplevelFor(a) {
        const all = ToplevelManager.toplevels.values
        for (let i = 0; i < all.length; i++)
            if ("0x" + all[i].HyprlandToplevel?.address === a) return all[i]
        return null
    }
    readonly property string wallSrc: WallpaperState.videoMode
        ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
        : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
    readonly property color glow: Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                  ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent

    // ── fond ──────────────────────────────────────────────────────────────
    Image { id: wall; anchors.fill: parent; visible: false; source: root.wallSrc; fillMode: Image.PreserveAspectCrop
            asynchronous: true; sourceSize.width: 1280 }
    MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blur: 1; blurMax: 64; opacity: root.ez }
    Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: 0.55 * root.ez }
    MouseArea {
        anchors.fill: parent
        onClicked: root.leave(root.startIdx, "", false)
        onWheel: (w) => { if (!wheelT.running) { root.pickWs(root.selWs + (w.angleDelta.y > 0 ? -1 : 1)); wheelT.start() } }
    }
    Timer { id: wheelT; interval: 140 }

    // ── le bandeau ────────────────────────────────────────────────────────
    Item {
        id: stage
        anchors.fill: parent
        // k = 1/scale au départ : la carte centrale couvre tout l'écran
        readonly property real k: 1 / root.sc + (1 - 1 / root.sc) * root.ez
        transform: Scale { origin.x: stage.width / 2; origin.y: stage.height / 2; xScale: stage.k; yScale: stage.k }

        property int dropTarget: -1
        function idxAt(gy) { return Math.round(root.pos + (gy - root.height / 2) / ((root.ch + root.gap) * stage.k)) }

        Repeater {
            model: root.wsList
            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property real dist: Math.abs(index - root.pos)
                readonly property bool near: dist < 1.6
                readonly property bool sel: index === root.selWs
                readonly property bool hov: root.hoverWs === index && root.dragAddr === ""
                x: (root.width - root.cw) / 2
                y: (root.height - root.ch) / 2 + (index - root.pos) * (root.ch + root.gap)
                width: root.cw; height: root.ch
                visible: y + height > -root.height && y < root.height * 2
                scale: (1 - 0.06 * Math.min(1, dist) * root.ez) * (hov ? 1 + 0.03 * root.ez : 1)
                opacity: hov ? 1 : 1 - 0.4 * Math.min(1, dist) * root.ez
                Behavior on scale { enabled: root.ez >= 1; NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: root.ez >= 1; NumberAnimation { duration: Appearance.dur(220) } }

                // halo de la carte choisie
                Rectangle { id: cGlow; anchors.fill: parent; radius: box.radius; color: root.glow; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: cGlow; source: cGlow; autoPaddingEnabled: true
                    blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.5
                    opacity: (stage.dropTarget === card.index ? 0.7 : card.hov ? 0.5 : card.sel && root.halo ? 0.45 : 0) * root.ez
                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(250) } }
                }

                ClippingRectangle {
                    id: box
                    anchors.fill: parent
                    radius: 22 * root.ez
                    color: Appearance.colors.bg
                    Image { anchors.fill: parent; source: root.wallSrc; fillMode: Image.PreserveAspectCrop; asynchronous: true
                            sourceSize.width: 1600; visible: !card.modelData.plus }
                    Rectangle { anchors.fill: parent; visible: card.modelData.plus; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.04) }
                    Text {
                        anchors.centerIn: parent; visible: card.modelData.plus
                        text: "+"; font.family: Appearance.font.family; font.pixelSize: root.ch * 0.3; font.weight: Font.Thin
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, stage.dropTarget === card.index ? 0.8 : 0.3)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverWs = card.index
                        onExited: if (root.hoverWs === card.index) root.hoverWs = -1
                        onClicked: root.leave(card.index, "", true)
                    }

                    // fenêtres
                    Repeater {
                        model: ScriptModel { objectProp: "address"; values: card.modelData.plus ? [] : root.winsOf(card.modelData.id) }
                        delegate: Item {
                            id: win
                            required property var modelData
                            required property int index
                            readonly property bool on: card.sel && root.selWin === modelData.address
                            readonly property bool dying: root.dying === modelData.address
                            readonly property real s: root.cw / root.monW
                            x: (modelData.at[0] - (root.mon ? root.mon.x : 0)) * s
                            y: (modelData.at[1] - (root.mon ? root.mon.y : 0)) * s
                            width: modelData.size[0] * s; height: modelData.size[1] * s
                            z: modelData.floating ? 10 + index : index
                            scale: dying ? 0.5 : on ? 1 + 0.025 * root.ez : wMa.containsMouse ? 1.01 : 1
                            opacity: dying ? 0 : root.dragAddr === modelData.address ? 0.25 : 1
                            Behavior on scale { NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutBack } }
                            Behavior on opacity { NumberAnimation { duration: Appearance.dur(240) } }

                            // halo de la fenêtre choisie
                            Rectangle { id: wGlow; anchors.fill: parent; radius: 12; color: root.glow; visible: false; layer.enabled: true }
                            MultiEffect {
                                anchors.fill: wGlow; source: wGlow; autoPaddingEnabled: true
                                blurEnabled: true; blur: 1; blurMax: 48; blurMultiplier: 1.2
                                opacity: win.on && root.halo ? (0.55 + 0.25 * pulse.v) * root.ez : 0
                                Behavior on opacity { NumberAnimation { duration: Appearance.dur(220) } }
                            }
                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 10 * root.ez
                                color: ColorUtils.applyAlpha(Appearance.colors.surface, 0.9)
                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    captureSource: root.shown && card.near ? root.toplevelFor(win.modelData.address) : null
                                    live: card.near
                                }
                                Image {
                                    anchors.centerIn: parent
                                    visible: !shot.hasContent
                                    readonly property real sz: Math.min(parent.width, parent.height) * 0.3
                                    width: sz; height: sz; sourceSize: Qt.size(sz, sz)
                                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(win.modelData.class)?.icon ?? win.modelData.class, "application-x-executable")
                                }
                            }
                            Rectangle {
                                anchors.fill: parent; radius: 10 * root.ez; color: "transparent"
                                border.width: win.on ? 3 : 0; border.color: root.glow
                                opacity: root.ez
                            }
                            // titre de la fenêtre choisie
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                                width: Math.min(parent.width - 20, tRow.implicitWidth + 28); height: 38; radius: 19
                                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.88)
                                opacity: win.on ? root.ez : 0
                                Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
                                Row {
                                    id: tRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Image { width: 22; height: 22; sourceSize: Qt.size(22, 22); anchors.verticalCenter: parent.verticalCenter
                                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(win.modelData.class)?.icon ?? win.modelData.class, "application-x-executable") }
                                    Text { text: win.modelData.title; elide: Text.ElideRight; width: Math.min(implicitWidth, win.width - 90)
                                           font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            MouseArea {
                                id: wMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: drag.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                preventStealing: true
                                onEntered: { root.hoverWs = card.index; if (card.sel && !drag.dragging) root.selWin = win.modelData.address }
                                onExited: if (root.hoverWs === card.index) root.hoverWs = -1
                                onPressed: (m) => { drag.start = mapToItem(null, m.x, m.y); drag.dragging = false }
                                onPositionChanged: (m) => {
                                    if (!pressed) return
                                    const p = mapToItem(null, m.x, m.y)
                                    if (!drag.dragging && Math.abs(p.x - drag.start.x) + Math.abs(p.y - drag.start.y) > 14) {
                                        drag.dragging = true
                                        const c = win.mapToItem(null, win.width / 2, win.height / 2)
                                        root.beginDrag(win.modelData, card.index, Qt.point(c.x, c.y),
                                                       win.width * stage.k * card.scale, win.height * stage.k * card.scale)
                                    }
                                    if (drag.dragging) root.moveDrag(p)
                                }
                                onReleased: (m) => {
                                    if (drag.dragging) root.endDrag()
                                    else if (m.button === Qt.MiddleButton) root.dying = win.modelData.address
                                    else root.leave(card.index, win.modelData.address, true)
                                    drag.dragging = false
                                }
                                onCanceled: { if (drag.dragging) root.endDrag(); drag.dragging = false }
                                QtObject { id: drag; property point start; property bool dragging: false }
                            }
                        }
                    }
                }

                // pastille du survol
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 18
                    width: gLbl.implicitWidth + 32; height: 40; radius: 20
                    color: root.glow
                    opacity: card.hov ? root.ez : 0
                    scale: card.hov ? 1 : 0.85
                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(180) } }
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutBack } }
                    Text {
                        id: gLbl; anchors.centerIn: parent
                        text: card.modelData.plus ? "󰐕  Créer l'espace " + card.modelData.id : "󰁔  Aller sur l'espace " + card.modelData.id
                        font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                        color: Appearance.colors.bg
                    }
                }

                // à gauche : numéro, nombre de fenêtres, icônes
                Column {
                    anchors.right: parent.left; anchors.rightMargin: 46
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.ez * (card.sel ? 1 : 0.55)
                    spacing: 6
                    transform: Translate { x: (1 - root.ez) * -60 }
                    Text {
                        anchors.right: parent.right
                        text: card.modelData.plus ? "+" : card.modelData.id
                        font.family: "JetBrains Mono"; font.weight: Font.Thin; font.pixelSize: 150
                        color: card.sel ? root.glow : Appearance.colors.fg
                    }
                    Text {
                        anchors.right: parent.right
                        readonly property int n: card.modelData.plus ? 0 : root.winsOf(card.modelData.id).length
                        text: card.modelData.plus ? "nouvel espace" : n === 0 ? "vide" : n + (n > 1 ? " fenêtres" : " fenêtre")
                        font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.dim
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 6
                        Repeater {
                            model: card.modelData.plus ? [] : root.winsOf(card.modelData.id).slice(0, 6)
                            Image { required property var modelData; width: 26; height: 26; sourceSize: Qt.size(26, 26)
                                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(modelData.class)?.icon ?? modelData.class, "application-x-executable") }
                        }
                    }
                }
            }
        }
    }
    QtObject {
        id: pulse
        property real v: 0
        property var a: SequentialAnimation {
            running: root.shown && Appearance.animationsEnabled; loops: Animation.Infinite
            NumberAnimation { target: pulse; property: "v"; to: 1; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { target: pulse; property: "v"; to: 0; duration: 1100; easing.type: Easing.InOutSine }
        }
    }

    // ── glisser une fenêtre : vignette qui suit le curseur, au-dessus de tout ──
    property string dragAddr: ""
    property var dragWin: null
    property int dragFrom: -1
    property point dragOrigin
    property real px: 0
    property real py: 0
    property real pw: 0
    property real ph: 0
    property real pScale: 1
    property real pOp: 1
    function beginDrag(w, from, c, ww, hh) {
        dropAnim.stop()
        dragWin = w; dragAddr = w.address; dragFrom = from; dragOrigin = c
        // vignette plafonnée : on voit où on la lâche
        const f = Math.min(1, 420 / Math.max(ww, hh))
        pw = ww * f; ph = hh * f; px = c.x; py = c.y; pScale = 1; pOp = 1
    }
    function moveDrag(p) {
        px = p.x; py = p.y
        const t = stage.idxAt(p.y)
        stage.dropTarget = (t >= 0 && t < wsList.length && t !== dragFrom) ? t : -1
        edgeT.dir = p.y < height * 0.12 ? -1 : p.y > height * 0.88 ? 1 : 0
    }
    function endDrag() {
        edgeT.dir = 0
        const t = stage.dropTarget
        if (t >= 0) {
            moveWin(dragAddr, t)
            dropTo.x = width / 2; dropTo.y = height / 2 + (t - pos) * (ch + gap) * stage.k
            dropScale.to = 0.25
        } else {
            dropTo.x = dragOrigin.x; dropTo.y = dragOrigin.y
            dropScale.to = 1
        }
        stage.dropTarget = -1
        dropAnim.restart()
    }
    QtObject { id: dropTo; property real x; property real y }
    SequentialAnimation {
        id: dropAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "px"; to: dropTo.x; duration: Appearance.dur(300); easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "py"; to: dropTo.y; duration: Appearance.dur(300); easing.type: Easing.InOutCubic }
            NumberAnimation { id: dropScale; target: root; property: "pScale"; duration: Appearance.dur(300); easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "pOp"; to: 0; duration: Appearance.dur(300); easing.type: Easing.InQuad }
        }
        ScriptAction { script: { root.dragAddr = ""; root.dragWin = null } }
    }
    // défilement automatique près des bords pendant un glisser
    Timer {
        id: edgeT
        property int dir: 0
        running: dir !== 0 && root.dragAddr !== ""
        interval: 480; repeat: true; triggeredOnStart: true
        onTriggered: {
            const t = Math.max(0, Math.min(root.wsList.length - 1, root.selWs + dir))
            if (t !== root.selWs) { root.selWs = t; root.moveDrag(Qt.point(root.px, root.py)) }
        }
    }
    Item {
        visible: root.dragAddr !== ""
        x: root.px - width / 2; y: root.py - height / 2
        width: root.pw; height: root.ph
        scale: root.pScale * (dropAnim.running ? 1 : 1.04)
        opacity: root.pOp
        rotation: dropAnim.running ? 0 : 2
        Behavior on rotation { NumberAnimation { duration: Appearance.dur(200) } }
        RectangularShadow { anchors.fill: parent; radius: 12; blur: 40; spread: 4; color: "#a0000000"; offset: Qt.vector2d(0, 14) }
        ClippingRectangle {
            anchors.fill: parent; radius: 12
            color: Appearance.colors.surface
            border.width: 2; border.color: stage.dropTarget >= 0 ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.3)
            ScreencopyView { anchors.fill: parent; captureSource: root.dragAddr ? root.toplevelFor(root.dragAddr) : null; live: true }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom; anchors.topMargin: 12
            visible: !dropAnim.running
            width: dLbl.implicitWidth + 28; height: 34; radius: 17
            color: stage.dropTarget >= 0 ? root.glow : ColorUtils.applyAlpha(Appearance.colors.bg, 0.9)
            Text {
                id: dLbl; anchors.centerIn: parent
                text: stage.dropTarget >= 0
                      ? "󰁔  " + (root.wsList[stage.dropTarget].plus ? "nouvel espace" : "espace " + root.wsList[stage.dropTarget].id)
                      : "lâcher sur un autre espace"
                font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.DemiBold
                color: stage.dropTarget >= 0 ? Appearance.colors.bg : Appearance.colors.fg
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label
        property bool on: false
        signal tap()
        width: cl.implicitWidth + 26; height: 36; radius: 18
        color: on ? root.glow : ColorUtils.applyAlpha(Appearance.colors.bg, cMa.containsMouse ? 0.95 : 0.8)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
        Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
        Text { id: cl; anchors.centerIn: parent; text: chip.label; font.family: Appearance.font.family; font.pixelSize: 14
               color: chip.on ? Appearance.colors.bg : Appearance.colors.fg }
        MouseArea { id: cMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.tap() }
    }

    // ── réglages rapides : taille, halo ───────────────────────────────────
    Row {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: 40; anchors.topMargin: 30
        spacing: 10
        opacity: root.ez
        Chip { label: "−"; onTap: root.zoom(-0.05) }
        Chip { label: Math.round(Number(Config.get("overview.scale", 0.5)) * 100) + " %"; onTap: Config.set("overview.scale", null) }
        Chip { label: "+"; onTap: root.zoom(0.05) }
        Item { width: 6; height: 1 }
        Chip { label: "󰛨  Halo"; on: root.halo; onTap: root.toggleHalo() }
    }

    // ── rail à droite ─────────────────────────────────────────────────────
    Column {
        anchors.right: parent.right; anchors.rightMargin: 48
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        opacity: root.ez
        transform: Translate { x: (1 - root.ez) * 60 }
        Repeater {
            model: root.wsList
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool sel: index === root.selWs
                anchors.horizontalCenter: parent.horizontalCenter
                width: 10; height: sel ? 44 : 10; radius: 5
                color: sel ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, modelData.plus ? 0.15 : 0.4)
                Behavior on height { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack } }
                MouseArea { anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: root.pickWs(index); onClicked: root.leave(index, "", true) }
            }
        }
    }

    Rectangle {
        anchors.centerIn: hints
        width: hints.implicitWidth + 36; height: hints.implicitHeight + 16; radius: height / 2
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.85)
        opacity: root.ez
    }
    Text {
        id: hints
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 22
        opacity: 0.85 * root.ez
        text: "↑↓ espaces  ·  ←→ fenêtres  ·  entrée aller  ·  1-9 sauter  ·  x fermer  ·  maj+↑↓ ou glisser : déplacer  ·  − + taille  ·  h halo  ·  échap"
        font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim
    }
}
