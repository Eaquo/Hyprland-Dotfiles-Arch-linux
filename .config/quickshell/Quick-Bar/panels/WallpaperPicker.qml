import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// WallpaperPicker — sélecteur de fond d'écran au clavier (SUPER+W, ALT+W = vidéos),
// `qs ipc call wallpicker toggle | videos | random`.
// Carrousel en perspective : la vignette du centre est grande, les autres s'inclinent et
// s'effacent ; la fenêtre prend la couleur dominante du fond sélectionné.
//   ←/→ (ou molette) parcourir · Entrée appliquer · Tab images/vidéos · taper = filtrer
//   Ctrl+R au hasard · Échap fermer. Application : WallpaperState (même logique que l'onglet Wall).
PanelWindow {
    id: root

    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }
    color: "transparent"
    visible: windowVisible
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:wallpicker"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.wallpaperOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Données ───────────────────────────────────────────────────────────
    readonly property string imgDir: Config.dir("wallpaper.dir", "~/Pictures/wallpapers")
    readonly property string vidDir: Config.dir("wallpaper.videos", imgDir + "/Video")
    property var items: []
    property string kind: "image"                  // image · video
    property string query: ""
    readonly property var shown: items.filter(it => it.type === kind
        && (query === "" || it.path.split("/").pop().toLowerCase().includes(query.toLowerCase())))
    readonly property int imgCount: items.filter(it => it.type === "image").length
    readonly property int vidCount: items.filter(it => it.type === "video").length
    readonly property var cur: shown.length ? shown[Math.max(0, Math.min(view.currentIndex, shown.length - 1))] : null
    function load() { listProc.running = false; listProc.running = true }
    Process {
        id: listProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/list-wallpapers.sh", root.imgDir, root.vidDir]
        stdout: StdioCollector { onStreamFinished: { try { root.items = JSON.parse(text); root.focusCurrent() } catch (e) {} } }
    }
    // se placer sur le fond actuel
    function focusCurrent() {
        const i = shown.findIndex(it => it.path === WallpaperState.currentWall)
        view.currentIndex = i >= 0 ? i : 0
    }
    onKindChanged: Qt.callLater(focusCurrent)
    onQueryChanged: view.currentIndex = 0

    function apply() {
        if (!cur) return
        if (cur.type === "video") WallpaperState.applyVideo(cur.path)
        else WallpaperState.applyImage(cur.path)
        Popups.wallpaperOpen = false
    }
    // Au hasard : applique tout de suite une image tirée au hasard (comme l'entrée « random » de l'ancien menu)
    function random() {
        WallpaperState.randomWall()
        Popups.wallpaperOpen = false
    }

    // ── Ouverture / fermeture ─────────────────────────────────────────────
    property bool windowVisible: false
    // Créé à l'ouverture et détruit après la fermeture (LazyLoader dans shell.qml) : rien en mémoire
    // quand il est fermé. Les commandes IPC « wallpicker » sont dans shell.qml.
    function openNow() {
        closeTimer.stop(); root.windowVisible = true; root.query = ""; search.text = ""
        root.load(); keys.forceActiveFocus()
        closeAnim.stop(); openAnim.restart()
    }
    Component.onCompleted: { root.kind = Popups.wallKind; if (Popups.wallpaperOpen) openNow() }
    Connections {
        target: Popups
        function onWallpaperOpenChanged() {
            if (Popups.wallpaperOpen) root.openNow()
            else { openAnim.stop(); closeAnim.restart(); closeTimer.restart() }
        }
    }
    Timer { id: closeTimer; interval: Appearance.dur(700) + 40; onTriggered: root.windowVisible = false }

    // ── Clavier ───────────────────────────────────────────────────────────
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { if (search.text !== "") search.text = ""; else Popups.wallpaperOpen = false }
            else if (e.key === Qt.Key_Left)  view.decrementCurrentIndex()
            else if (e.key === Qt.Key_Right) view.incrementCurrentIndex()
            else if (e.key === Qt.Key_Home)  view.currentIndex = 0
            else if (e.key === Qt.Key_End)   view.currentIndex = root.shown.length - 1
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply()
            else if (e.key === Qt.Key_Tab) root.kind = root.kind === "image" ? "video" : "image"
            else if (e.key === Qt.Key_R && (e.modifiers & Qt.ControlModifier)) root.random()
            else if (e.key === Qt.Key_Backspace) search.text = search.text.slice(0, -1)
            else if (e.text && e.text.length === 1 && e.text >= " ") search.text += e.text
            else return
            e.accepted = true
        }
    }

    // Voile : clic à côté = fermer
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Popups.wallpaperOpen ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(260) } }
        MouseArea { anchors.fill: parent; onClicked: Popups.wallpaperOpen = false }
    }

    // ── Couleur dominante de la vignette centrale ─────────────────────────
    property color glow: Appearance.colors.accent
    Behavior on glow { ColorAnimation { duration: Appearance.dur(300) } }
    Canvas {
        id: sampler
        width: 16; height: 16; visible: false
        property string src: root.cur ? "file://" + root.cur.thumb : ""
        onSrcChanged: if (src !== "") loadImage(src)
        onImageLoaded: requestPaint()
        onPaint: {
            if (!src) return
            const g = getContext("2d"); g.clearRect(0, 0, 16, 16); g.drawImage(src, 0, 0, 16, 16)
            const d = g.getImageData(0, 0, 16, 16).data
            let best = [128, 128, 128], score = -1
            for (let i = 0; i < d.length; i += 4) {
                const mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2])
                const sc = (mx ? (mx - mn) / mx : 0) * (0.4 + 0.6 * mx / 255)
                if (sc > score) { score = sc; best = [d[i], d[i + 1], d[i + 2]] }
            }
            root.glow = Qt.rgba(best[0] / 255, best[1] / 255, best[2] / 255, 1)
        }
    }

    // ── Fenêtre : forme animée (ligne → pilule → déroulé) ─────────────────
    readonly property real fullW: Math.min(1700, width - 120)
    readonly property real fullH: Math.min(560, height - 160)
    // état de départ = fermé (le panneau est créé à l'ouverture : sinon 1re image en grand, puis l'animation)
    property real mw: 2
    property real mh: 2
    property real content: 0
    SequentialAnimation {
        id: openAnim
        ScriptAction { script: { root.mw = 2; root.mh = 2; root.content = 0 } }
        NumberAnimation { target: root; property: "mw"; to: root.fullW * 0.7; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(280); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: root; property: "mw"; to: root.fullW; duration: Appearance.dur(280); easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: root.fullH; duration: Appearance.dur(440); easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(200) }
                NumberAnimation { target: root; property: "content"; to: 1; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: { root.mw = Qt.binding(() => root.fullW); root.mh = Qt.binding(() => root.fullH) } }
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "content"; to: 0; duration: Appearance.dur(140) }
        NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(280); easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mw"; to: 2; duration: Appearance.dur(240); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "mh"; to: 2; duration: Appearance.dur(240); easing.type: Easing.InCubic }
        }
    }

    // halo de la couleur du fond sélectionné
    Rectangle {
        id: halo
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius
        color: root.glow
        opacity: 0.55 * root.content
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        source: halo
        x: halo.x; y: halo.y; width: halo.width; height: halo.height
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.6
        opacity: halo.opacity
        autoPaddingEnabled: true
    }

    ClippingRectangle {
        id: box
        x: (root.width - root.mw) / 2
        y: (root.height - root.mh) / 2
        width: root.mw; height: root.mh
        radius: Math.min(Appearance.cornerRadius + 6, height / 2)
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96)
        border.width: 2
        border.color: ColorUtils.applyAlpha(root.glow, 0.85)
        Behavior on border.color { ColorAnimation { duration: Appearance.dur(300) } }
        MouseArea { anchors.fill: parent; onWheel: (w) => w.angleDelta.y > 0 ? view.decrementCurrentIndex() : view.incrementCurrentIndex() }

        Item {
            x: (root.mw - root.fullW) / 2; y: (root.mh - root.fullH) / 2
            width: root.fullW; height: root.fullH
            opacity: root.content
            transform: Translate { y: (1 - root.content) * 12 }

            // ── En-tête : titre, images/vidéos, recherche ──
            RowLayout {
                id: head
                x: 26; y: 20; width: parent.width - 52
                spacing: 14
                Rectangle { width: 32; height: 32; radius: 10; color: root.glow
                    Text { anchors.centerIn: parent; text: "󰸉"; font.family: Appearance.font.family; font.pixelSize: 17; color: Appearance.textOn(root.glow) } }
                Text { text: "Fond d'écran"; font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold; color: Appearance.colors.fg }
                Item { Layout.preferredWidth: 10 }
                Repeater {
                    model: [["image", "󰋩  Images", root.imgCount], ["video", "󰕧  Vidéos", root.vidCount]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: root.kind === modelData[0]
                        implicitWidth: kt.implicitWidth + 26; implicitHeight: 34; radius: 10
                        color: on ? ColorUtils.applyAlpha(root.glow, 0.25) : (kMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent")
                        border.width: 1; border.color: on ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                        Text { id: kt; anchors.centerIn: parent; text: parent.modelData[1] + "  " + parent.modelData[2]
                               font.family: Appearance.font.family; font.pixelSize: 13; color: parent.on ? Appearance.colors.fg : Appearance.colors.dim }
                        MouseArea { id: kMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.kind = parent.modelData[0] }
                    }
                }
                Item { Layout.fillWidth: true }
                // recherche (on tape directement, sans cliquer)
                Rectangle {
                    implicitWidth: 280; implicitHeight: 34; radius: 10
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
                    border.width: 1; border.color: search.text !== "" ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.dim }
                    Text {
                        id: search
                        property string value: ""
                        x: 32; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideLeft
                        text: ""
                        onTextChanged: root.query = text
                        font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.fg
                    }
                    Text { x: 32; anchors.verticalCenter: parent.verticalCenter; visible: search.text === ""
                           text: "tape pour filtrer…"; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim }
                }
                // un fond par espace de travail (+ recoloration facultative)
                Chip {
                    on: WallpaperState.perWorkspace
                    label: "󰕰  Un fond par espace"
                    onTap: WallpaperState.perWorkspace = !WallpaperState.perWorkspace
                }
                Chip {
                    visible: WallpaperState.perWorkspace
                    on: WallpaperState.wsRecolor
                    label: "󰏘  recolorer"
                    onTap: WallpaperState.wsRecolor = !WallpaperState.wsRecolor
                }
                Chip { on: false; label: "󰒝  Au hasard"; onTap: root.random() }
                SetBtn { icon: "󰅖"; tip: "fermer (Échap)"; onTap: Popups.wallpaperOpen = false }
            }

            // ── Carrousel en perspective ──
            PathView {
                id: view
                anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 18; bottom: foot.top; bottomMargin: 8 }
                model: root.shown
                pathItemCount: Math.min(9, Math.max(1, root.shown.length))
                preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Appearance.dur(320)
                snapMode: PathView.SnapToItem
                clip: true
                readonly property real cw: Math.min(560, height * 1.55)     // largeur de la vignette centrale
                path: Path {
                    startX: 0; startY: view.height / 2
                    PathAttribute { name: "sc"; value: 0.42 }
                    PathAttribute { name: "tilt"; value: 52 }
                    PathAttribute { name: "op"; value: 0.15 }
                    PathAttribute { name: "zz"; value: 0 }
                    PathLine { x: view.width * 0.38; y: view.height / 2 }
                    PathAttribute { name: "sc"; value: 0.72 }
                    PathAttribute { name: "tilt"; value: 38 }
                    PathAttribute { name: "op"; value: 0.7 }
                    PathAttribute { name: "zz"; value: 5 }
                    PathLine { x: view.width * 0.5; y: view.height / 2 }
                    PathAttribute { name: "sc"; value: 1.0 }
                    PathAttribute { name: "tilt"; value: 0 }
                    PathAttribute { name: "op"; value: 1.0 }
                    PathAttribute { name: "zz"; value: 10 }
                    PathLine { x: view.width * 0.62; y: view.height / 2 }
                    PathAttribute { name: "sc"; value: 0.72 }
                    PathAttribute { name: "tilt"; value: -38 }
                    PathAttribute { name: "op"; value: 0.7 }
                    PathAttribute { name: "zz"; value: 5 }
                    PathLine { x: view.width; y: view.height / 2 }
                    PathAttribute { name: "sc"; value: 0.42 }
                    PathAttribute { name: "tilt"; value: -52 }
                    PathAttribute { name: "op"; value: 0.15 }
                    PathAttribute { name: "zz"; value: 0 }
                }
                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool isCur: PathView.isCurrentItem
                    readonly property bool active: modelData.path === WallpaperState.currentWall
                    width: view.cw; height: view.cw * 0.6
                    scale: PathView.sc
                    opacity: PathView.op
                    z: PathView.zz
                    transform: Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.PathView.tilt }
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 18
                        color: Appearance.colors.color0
                        border.width: card.isCur ? 3 : 1
                        border.color: card.isCur ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                        Image {
                            anchors.fill: parent
                            source: "file://" + card.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(640, 384)
                            asynchronous: true; smooth: true
                        }
                        // badges : vidéo, fond actuel
                        Row {
                            anchors { left: parent.left; top: parent.top; margins: 12 }
                            spacing: 6
                            Rectangle { visible: card.modelData.type === "video"; width: vt.implicitWidth + 16; height: 24; radius: 8; color: ColorUtils.applyAlpha("#000000", 0.6)
                                Text { id: vt; anchors.centerIn: parent; text: "󰐊 vidéo"; font.family: Appearance.font.family; font.pixelSize: 11; color: "white" } }
                            Rectangle { visible: card.active; width: at.implicitWidth + 16; height: 24; radius: 8; color: root.glow
                                Text { id: at; anchors.centerIn: parent; text: "✓ actuel"; font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.textOn(root.glow) } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.isCur ? root.apply() : view.currentIndex = card.index
                    }
                }
            }
            Text {
                anchors.centerIn: view
                visible: root.shown.length === 0
                text: listProc.running ? "Lecture du dossier…" : (root.query !== "" ? "Aucun fond ne correspond à « " + root.query + " »" : "Aucun fond dans " + (root.kind === "video" ? root.vidDir : root.imgDir))
                font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.dim
            }

            // ── Pied : nom, position, raccourcis ──
            RowLayout {
                id: foot
                x: 26; width: parent.width - 52
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                spacing: 16
                Text { Layout.fillWidth: true; elide: Text.ElideMiddle
                       text: root.cur ? root.cur.path.split("/").pop() : ""
                       font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                Text { text: root.shown.length ? (view.currentIndex + 1) + " / " + root.shown.length : ""
                       font.family: "JetBrains Mono"; font.pixelSize: 12; color: Appearance.colors.dim }
                Text { text: "←→ parcourir · Entrée appliquer · Tab images/vidéos · Ctrl+R au hasard · Échap"
                       font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                Rectangle {
                    implicitWidth: apT.implicitWidth + 30; implicitHeight: 38; radius: 12
                    color: apMa.containsMouse ? Qt.lighter(root.glow, 1.15) : root.glow
                    Text { id: apT; anchors.centerIn: parent; text: "󰄬  Appliquer"; font.family: Appearance.font.family; font.pixelSize: 14
                           font.weight: Font.Bold; color: Appearance.textOn(root.glow) }
                    MouseArea { id: apMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.apply() }
                }
            }
        }
    }

    // interrupteur / bouton texte de l'en-tête
    component Chip: Rectangle {
        id: ch
        property bool on: false
        property string label: ""
        signal tap()
        implicitWidth: chT.implicitWidth + 24; implicitHeight: 34; radius: 10
        color: on ? ColorUtils.applyAlpha(root.glow, 0.28) : (chMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.04))
        border.width: 1; border.color: on ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
        Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
        Text { id: chT; anchors.centerIn: parent; text: ch.label + (ch.on ? "  ✓" : "")
               font.family: Appearance.font.family; font.pixelSize: 13; color: ch.on ? Appearance.colors.fg : Appearance.colors.dim }
        MouseArea { id: chMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.tap() }
    }

    // petit bouton rond de l'en-tête
    component SetBtn: Rectangle {
        id: sb
        property string icon: ""
        property string tip: ""
        signal tap()
        implicitWidth: 34; implicitHeight: 34; radius: 10
        color: sbMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
        Text { anchors.centerIn: parent; text: sb.icon; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg }
        MouseArea { id: sbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sb.tap() }
    }
}
