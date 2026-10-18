import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.core.functions

// WallpaperCinema — sélecteur « Cinéma » (ALT+W, `qs ipc call wallcinema toggle`).
// L'aperçu du fond sélectionné remplit l'écran (fondu enchaîné + lent travelling), une typo géante
// à gauche, une pellicule en arc à droite dont la vignette courante zoome. Appliquer : un cercle part de la vignette et envahit
// l'écran, puis le fond est posé (WallpaperState, même logique que l'onglet Wall et SUPER+W).
//   ↑/↓ ou molette · Entrée appliquer · Tab images/vidéos · Ctrl+R au hasard · Échap
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
    WlrLayershell.namespace: "quickshell:wallcinema"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.wallCinemaOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Données ───────────────────────────────────────────────────────────
    readonly property string imgDir: Config.dir("wallpaper.dir", "~/Pictures/wallpapers")
    readonly property string vidDir: Config.dir("wallpaper.videos", imgDir + "/Video")
    property var items: []
    property string kind: "image"
    readonly property var shown: items.filter(it => it.type === kind)
    readonly property var cur: shown.length ? shown[Math.max(0, Math.min(strip.currentIndex, shown.length - 1))] : null
    readonly property string curSrc: cur ? "file://" + (cur.type === "video" ? cur.thumb : cur.path) : ""
    Process {
        id: listProc
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/list-wallpapers.sh", root.imgDir, root.vidDir]
        stdout: StdioCollector { onStreamFinished: { try { root.items = JSON.parse(text); root.focusCurrent() } catch (e) {} } }
    }
    function focusCurrent() {
        const i = shown.findIndex(it => it.path === WallpaperState.currentWall)
        strip.currentIndex = i >= 0 ? i : 0
    }
    onKindChanged: Qt.callLater(focusCurrent)

    // ── Ouverture / fermeture ─────────────────────────────────────────────
    property bool windowVisible: false
    property real intro: 0            // 0 → 1 : fond, puis texte et pellicule
    Connections {
        target: Popups
        function onWallCinemaOpenChanged() {
            if (Popups.wallCinemaOpen) {
                closeTimer.stop(); root.windowVisible = true; reveal.d = 0; root.applying = false
                listProc.running = false; listProc.running = true; keys.forceActiveFocus()
                outAnim.stop(); inAnim.restart()
            } else { inAnim.stop(); outAnim.restart(); closeTimer.restart() }
        }
    }
    NumberAnimation { id: inAnim; target: root; property: "intro"; to: 1; duration: Appearance.dur(900); easing.type: Easing.OutCubic }
    NumberAnimation { id: outAnim; target: root; property: "intro"; to: 0; duration: Appearance.dur(380); easing.type: Easing.InCubic }
    Timer { id: closeTimer; interval: Appearance.dur(400) + 40; onTriggered: root.windowVisible = false }

    IpcHandler {
        target: "wallcinema"
        function toggle() { if (!Popups.wallCinemaOpen) root.kind = "image"; Popups.wallCinemaOpen = !Popups.wallCinemaOpen }
        function videos() { root.kind = "video"; Popups.wallCinemaOpen = true }
    }

    // ── Appliquer : le cercle de révélation part de la vignette ──────────
    property bool applying: false
    function apply() {
        if (!cur || applying) return
        applying = true
        const c = strip.currentItem ? strip.currentItem.mapToItem(root.contentItem, strip.currentItem.width / 2, strip.currentItem.height / 2) : Qt.point(width / 2, height / 2)
        reveal.cx = c.x; reveal.cy = c.y; reveal.src = curSrc
        revealAnim.restart()
    }
    SequentialAnimation {
        id: revealAnim
        NumberAnimation { target: reveal; property: "d"; from: 0; to: 2.3 * Math.hypot(root.width, root.height); duration: Appearance.dur(760); easing.type: Easing.InOutCubic }
        ScriptAction { script: {
            if (root.cur.type === "video") WallpaperState.applyVideo(root.cur.path)
            else WallpaperState.applyImage(root.cur.path)
            Popups.wallCinemaOpen = false
        } }
    }

    // ── Clavier ───────────────────────────────────────────────────────────
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) Popups.wallCinemaOpen = false
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left) strip.decrementCurrentIndex()
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Right) strip.incrementCurrentIndex()
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.apply()
            else if (e.key === Qt.Key_Tab) root.kind = root.kind === "image" ? "video" : "image"
            else if (e.key === Qt.Key_R && (e.modifiers & Qt.ControlModifier)) { WallpaperState.randomWall(); Popups.wallCinemaOpen = false }
            else return
            e.accepted = true
        }
    }

    // ── Couleur dominante ─────────────────────────────────────────────────
    property color glow: Appearance.colors.accent
    Behavior on glow { ColorAnimation { duration: Appearance.dur(400) } }
    Canvas {
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

    // ── Aperçu plein écran : fondu enchaîné entre deux images + travelling ──
    Item {
        id: stage
        anchors.fill: parent
        opacity: root.intro
        clip: true
        property bool flip: false
        property real kb: 1.0
        SequentialAnimation on kb {
            running: root.windowVisible
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.09; duration: 9000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.09; to: 1.0; duration: 9000; easing.type: Easing.InOutSine }
        }
        Connections {
            target: root
            function onCurSrcChanged() {
                if (root.curSrc === "") return
                if (stage.flip) imgA.source = root.curSrc; else imgB.source = root.curSrc
                stage.flip = !stage.flip
            }
        }
        Image { id: imgA; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1920
                scale: stage.kb; opacity: !stage.flip && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(450) } } }
        Image { id: imgB; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1920
                scale: stage.kb; opacity: stage.flip && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(450) } } }
        // assombrissement à gauche (texte) et à droite (pellicule)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.82) }
                GradientStop { position: 0.38; color: Qt.rgba(0, 0, 0, 0.25) }
                GradientStop { position: 0.68; color: Qt.rgba(0, 0, 0, 0.15) }
                GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.78) }
            }
        }
        Rectangle { anchors.fill: parent; color: "transparent"
            gradient: Gradient { GradientStop { position: 0.75; color: "transparent" } GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) } } }
    }

    // ── Typo géante à gauche ──────────────────────────────────────────────
    Item {
        id: info
        x: 90 - (1 - root.intro) * 120
        width: root.width * 0.42; height: root.height
        opacity: root.intro
        // numéro du fond, immense et ajouré
        Text {
            id: bigNum
            x: -10; anchors.bottom: titleCol.top; anchors.bottomMargin: -60
            text: root.shown.length ? String(strip.currentIndex + 1).padStart(2, "0") : "--"
            font.family: Appearance.font.family; font.pixelSize: Math.min(360, root.height * 0.3); font.weight: Font.Black
            color: "transparent"
            style: Text.Outline; styleColor: ColorUtils.applyAlpha(root.glow, 0.55)
        }
        ColumnLayout {
            id: titleCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: root.height * 0.12 }
            spacing: 12
            Row {
                spacing: 10
                Rectangle { width: 46; height: 4; radius: 2; color: root.glow; anchors.verticalCenter: parent.verticalCenter }
                Text { text: (root.kind === "video" ? "VIDÉO" : "FOND D'ÉCRAN") + "  ·  " + (root.shown.length ? (strip.currentIndex + 1) + " / " + root.shown.length : "")
                       font.family: Appearance.font.family; font.pixelSize: 15; font.letterSpacing: 4; font.weight: Font.Bold; color: root.glow }
            }
            Text {
                Layout.fillWidth: true
                text: root.cur ? root.cur.path.split("/").pop().replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ") : ""
                elide: Text.ElideRight
                font.family: Appearance.font.family; font.pixelSize: Math.min(84, root.height * 0.07); font.weight: Font.Black
                font.capitalization: Font.AllUppercase
                color: "white"
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: ColorUtils.applyAlpha(root.glow, 0.8); shadowBlur: 0.9 }
            }
            Text {
                visible: !!root.cur && root.cur.path === WallpaperState.currentWall
                text: "✓  fond actuel"
                font.family: Appearance.font.family; font.pixelSize: 16; color: ColorUtils.applyAlpha("white", 0.75)
            }
            Item { Layout.preferredHeight: 26 }
            // onglets images / vidéos
            Row {
                spacing: 10
                Repeater {
                    model: [["image", "IMAGES"], ["video", "VIDÉOS"]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: root.kind === modelData[0]
                        width: kl.implicitWidth + 34; height: 40; radius: 20
                        color: on ? root.glow : Qt.rgba(1, 1, 1, kMa.containsMouse ? 0.14 : 0.07)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, on ? 0 : 0.2)
                        Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
                        Text { id: kl; anchors.centerIn: parent; text: parent.modelData[1]
                               font.family: Appearance.font.family; font.pixelSize: 13; font.letterSpacing: 3; font.weight: Font.Bold
                               color: parent.on ? Appearance.textOn(root.glow) : "white" }
                        MouseArea { id: kMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.kind = parent.modelData[0] }
                    }
                }
            }
            Text {
                Layout.topMargin: 18
                text: "↑ ↓  parcourir      ⏎  appliquer      ⇥  images / vidéos      Ctrl+R  au hasard      Échap  fermer"
                font.family: Appearance.font.family; font.pixelSize: 13; font.letterSpacing: 1; color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
    }

    // ── Pellicule en arc à droite ─────────────────────────────────────────
    PathView {
        id: strip
        x: root.width - width + (1 - root.intro) * 260
        width: Math.min(560, root.width * 0.3); height: root.height
        opacity: root.intro
        model: root.shown
        pathItemCount: Math.min(9, Math.max(1, root.shown.length))
        preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Appearance.dur(380)
        snapMode: PathView.SnapToItem
        // l'arc se bombe vers le centre de l'écran
        path: Path {
            startX: strip.width * 0.92; startY: -strip.height * 0.08
            PathAttribute { name: "sc"; value: 0.45 }
            PathAttribute { name: "op"; value: 0.0 }
            PathAttribute { name: "rot"; value: -16 }
            PathQuad { x: strip.width * 0.92; y: strip.height * 1.08; controlX: strip.width * 0.05; controlY: strip.height * 0.5 }
            PathAttribute { name: "sc"; value: 0.45 }
            PathAttribute { name: "op"; value: 0.0 }
            PathAttribute { name: "rot"; value: 16 }
            PathPercent { value: 1.0 }
        }
        delegate: Item {
            id: fr
            required property var modelData
            required property int index
            readonly property bool isCur: PathView.isCurrentItem
            width: 300; height: 180
            // la vignette courante zoome (pas d'anneau lumineux) et passe au premier plan
            scale: isCur ? 1.55 : 0.8
            transformOrigin: Item.Right
            opacity: isCur ? 1 : 0.62
            z: isCur ? 10 : 1
            rotation: isCur ? 0 : (index < strip.currentIndex ? -8 : 8)
            Behavior on scale { NumberAnimation { duration: Appearance.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            Behavior on rotation { NumberAnimation { duration: Appearance.dur(320); easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Appearance.dur(250) } }
            // halo flouté de la couleur dominante, comme SUPER+W (derrière la vignette courante)
            Rectangle {
                id: haloSrc
                anchors.fill: parent; anchors.margins: -10
                radius: 24; color: root.glow
                visible: false; layer.enabled: true
            }
            MultiEffect {
                anchors.fill: haloSrc
                source: haloSrc
                visible: fr.isCur
                opacity: fr.isCur ? 0.75 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.6
                autoPaddingEnabled: true
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: 16
                color: "#000000"
                border.width: fr.isCur ? 2 : 1; border.color: Qt.rgba(1, 1, 1, fr.isCur ? 0.7 : 0.25)
                Image { anchors.fill: parent; source: "file://" + fr.modelData.thumb; fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(480, 288); asynchronous: true }
                Rectangle { visible: fr.modelData.type === "video"; anchors { right: parent.right; top: parent.top; margins: 8 }
                            width: 26; height: 26; radius: 13; color: Qt.rgba(0, 0, 0, 0.6)
                            Text { anchors.centerIn: parent; text: "󰐊"; font.family: Appearance.font.family; font.pixelSize: 13; color: "white" } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: fr.isCur ? root.apply() : strip.currentIndex = fr.index }
        }
    }
    // molette n'importe où
    MouseArea {
        anchors.fill: parent; z: -1
        onWheel: (w) => w.angleDelta.y > 0 ? strip.decrementCurrentIndex() : strip.incrementCurrentIndex()
    }
    Text {
        anchors.centerIn: parent
        visible: root.shown.length === 0 && root.intro > 0.5
        text: listProc.running ? "Lecture du dossier…" : "Aucun fond dans " + (root.kind === "video" ? root.vidDir : root.imgDir)
        font.family: Appearance.font.family; font.pixelSize: 22; color: "white"
    }

    // ── Cercle de révélation (appliquer) ──────────────────────────────────
    ClippingRectangle {
        id: reveal
        property real cx: 0
        property real cy: 0
        property real d: 0
        property string src: ""
        visible: d > 0
        x: cx - d / 2; y: cy - d / 2; width: d; height: d
        radius: d / 2
        color: "black"
        border.width: d > 0 && d < 400 ? 3 : 0; border.color: root.glow
        Image {
            x: -reveal.x; y: -reveal.y; width: root.width; height: root.height
            source: reveal.src; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1920
        }
    }
}
