import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.core.functions

// AltTab — changer de fenêtre (ALT+Tab · ALT+MAJ+Tab · relâcher Alt = y aller).
// Carrousel en perspective (comme SUPER+W) d'aperçus live, reflet au sol ; les plus récentes d'abord,
// la précédente déjà choisie. Créé à l'ouverture, détruit après (LazyLoader dans shell.qml) ;
// IPC « alttab » dans shell.qml : next / prev / commit / cancel.
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
    WlrLayershell.namespace: "quickshell:alttab"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool shown: false
    property bool loading: false
    property bool leaving: false
    property var wins: []
    property int pendingSteps: 0         // Tab appuyés avant que la liste soit prête
    property real intro: 0               // 0 → 1 : les cartes arrivent
    property real out: 0                 // 0 → 1 : la carte choisie grandit, les autres s'envolent
    readonly property var cur: wins.length ? wins[Math.max(0, Math.min(view.currentIndex, wins.length - 1))] : null
    readonly property color glow: Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                  ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent

    // ── données ───────────────────────────────────────────────────────────
    function open() { if (shown || loading) return; loading = true; listProc.running = true }
    Component.onCompleted: if (Popups.altTabWanted) open()   // remise à zéro par shell.qml
    Process {
        id: listProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = []
                try { w = JSON.parse(text).filter(c => c.mapped && c.workspace.id > 0).sort((a, b) => a.focusHistoryID - b.focusHistoryID) } catch (e) {}
                root.loading = false
                if (!w.length) return
                // Alt relâché avant l'affichage : bascule directe, sans rien montrer
                if (root.quickCommit) {
                    const t = w[Math.min(1 + root.pendingSteps, w.length - 1) % w.length]
                    root.quickCommit = false; root.pendingSteps = 0
                    focusProc.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:" + t.address + "' }))"]
                    focusProc.running = true
                    return
                }
                root.wins = w
                view.currentIndex = Math.min(1 + root.pendingSteps, w.length - 1) % w.length
                root.pendingSteps = 0
                root.shown = true; root.leaving = false
                keys.forceActiveFocus()
                outAnim.stop(); root.out = 0; inAnim.restart()
            }
        }
    }
    function step(d) {
        if (leaving) return
        if (!shown) { pendingSteps += d; open(); return }
        view.currentIndex = (view.currentIndex + d + wins.length) % wins.length
    }
    Process { id: focusProc }
    property bool quickCommit: false
    function commit() {
        if (loading) { quickCommit = true; return }
        if (!shown || leaving || !cur) return
        leaving = true
        focusProc.command = ["hyprctl", "eval", "hl.config({ cursor = { no_warps = true } }) hl.dispatch(hl.dsp.focus({ window = 'address:" + cur.address + "' })) hl.config({ cursor = { no_warps = false } })"]
        focusProc.running = true
        inAnim.stop(); outAnim.restart()
    }
    function cancel() { if (!shown || leaving) return; leaving = true; inAnim.stop(); cancelAnim.restart() }

    NumberAnimation { id: inAnim; target: root; property: "intro"; from: 0; to: 1; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "out"; to: 1; duration: Appearance.dur(300); easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = false }
    }
    SequentialAnimation {
        id: cancelAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: Appearance.dur(220); easing.type: Easing.InCubic }
        ScriptAction { script: root.shown = false }
    }

    function toplevelFor(a) {
        const all = ToplevelManager.toplevels.values
        for (let i = 0; i < all.length; i++)
            if ("0x" + all[i].HyprlandToplevel?.address === a) return all[i]
        return null
    }
    function iconOf(cls) { return Quickshell.iconPath(DesktopEntries.heuristicLookup(cls)?.icon ?? cls, "application-x-executable") }

    // ── clavier (Tab passe d'abord par le raccourci Hyprland, qui appelle step) ──
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) root.cancel()
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.commit()
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.step(1)
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) root.step(-1)
            else return
            e.accepted = true
        }
        Keys.onReleased: (e) => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_AltGr) { root.commit(); e.accepted = true } }
    }

    // ── fond : léger assombrissement en dégradé ───────────────────────────
    Rectangle {
        anchors.fill: parent
        opacity: 0.55 * root.intro * (1 - root.out)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.75) }
            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95) }
        }
        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    // ── carrousel ─────────────────────────────────────────────────────────
    readonly property real cardH: Math.min(height * 0.42, 620)
    PathView {
        id: view
        anchors.fill: parent
        model: root.wins
        pathItemCount: Math.min(7, Math.max(1, root.wins.length))
        preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Appearance.dur(260)
        interactive: false
        readonly property real cy: root.height * 0.44
        path: Path {
            startX: -root.width * 0.05; startY: view.cy
            PathAttribute { name: "sc"; value: 0.45 }
            PathAttribute { name: "tilt"; value: 58 }
            PathAttribute { name: "op"; value: 0.0 }
            PathAttribute { name: "zz"; value: 0 }
            PathLine { x: root.width * 0.3; y: view.cy }
            PathAttribute { name: "sc"; value: 0.7 }
            PathAttribute { name: "tilt"; value: 40 }
            PathAttribute { name: "op"; value: 0.75 }
            PathAttribute { name: "zz"; value: 5 }
            PathLine { x: root.width * 0.5; y: view.cy }
            PathAttribute { name: "sc"; value: 1.0 }
            PathAttribute { name: "tilt"; value: 0 }
            PathAttribute { name: "op"; value: 1.0 }
            PathAttribute { name: "zz"; value: 10 }
            PathLine { x: root.width * 0.7; y: view.cy }
            PathAttribute { name: "sc"; value: 0.7 }
            PathAttribute { name: "tilt"; value: -40 }
            PathAttribute { name: "op"; value: 0.75 }
            PathAttribute { name: "zz"; value: 5 }
            PathLine { x: root.width * 1.05; y: view.cy }
            PathAttribute { name: "sc"; value: 0.45 }
            PathAttribute { name: "tilt"; value: -58 }
            PathAttribute { name: "op"; value: 0.0 }
            PathAttribute { name: "zz"; value: 0 }
        }
        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool isCur: PathView.isCurrentItem
            readonly property real aspect: Math.max(0.6, Math.min(2.4, modelData.size[0] / Math.max(1, modelData.size[1])))
            // arrivée en cascade depuis le bas, départ : la choisie grandit, les autres s'envolent
            readonly property real k: Math.max(0, Math.min(1, root.intro * 1.6 - Math.abs(index - view.currentIndex) * 0.12))
            width: root.cardH * aspect; height: root.cardH
            scale: PathView.sc * (0.85 + 0.15 * k) * (isCur ? 1 + root.out * 0.5 : 1 - root.out * 0.3)
            opacity: PathView.op * k * (isCur ? 1 - root.out * 0.9 : 1 - root.out)
            z: PathView.zz
            transform: [
                Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.PathView.tilt },
                Translate { y: (1 - card.k) * 160 + (card.isCur ? 0 : -root.out * 220) }
            ]

            // halo de la carte choisie
            Rectangle { id: cGlow; anchors.fill: parent; radius: box.radius; color: root.glow; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: cGlow; source: cGlow; autoPaddingEnabled: true
                blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.4
                opacity: card.isCur ? 0.45 : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
            }
            RectangularShadow { anchors.fill: parent; anchors.topMargin: 24; radius: box.radius; blur: 40; color: ColorUtils.applyAlpha("#000000", 0.6) }

            ClippingRectangle {
                id: box
                anchors.fill: parent
                radius: Math.min(26, Appearance.cornerRadius + 8)
                color: Appearance.colors.color0
                ScreencopyView {
                    id: shot
                    anchors.fill: parent
                    captureSource: root.shown && Math.abs(card.index - view.currentIndex) <= 2 ? root.toplevelFor(card.modelData.address) : null
                    live: card.isCur
                }
                Image {
                    anchors.centerIn: parent
                    visible: !shot.hasContent
                    width: parent.height * 0.3; height: width; sourceSize: Qt.size(128, 128)
                    source: root.iconOf(card.modelData.class)
                }
                Rectangle { anchors.fill: parent; radius: box.radius; color: "transparent"
                            border.width: card.isCur ? 3 : 1; border.color: card.isCur ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15) }
            }
            // reflet au sol
            ShaderEffectSource {
                id: refl
                sourceItem: box; live: card.isCur
                width: box.width; height: box.height * 0.35
                sourceRect: Qt.rect(0, box.height * 0.65, box.width, box.height * 0.35)
                y: box.height + 10
                transform: Scale { origin.y: refl.height / 2; yScale: -1 }
                opacity: 0.22
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true; maskSource: reflMask
                    maskThresholdMin: 0; maskSpreadAtMin: 1
                }
            }
            Item {
                id: reflMask
                width: refl.width; height: refl.height; visible: false; layer.enabled: true
                Rectangle { anchors.fill: parent; gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "white" } } }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { if (card.isCur) root.commit(); else view.currentIndex = card.index }
            }
        }
    }

    // ── la fenêtre choisie : icône, titre, application, espace ────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.cy + root.cardH / 2 + root.cardH * 0.42
        spacing: 10
        opacity: root.intro * (1 - root.out)
        transform: Translate { y: (1 - root.intro) * 30 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Image { width: 42; height: 42; sourceSize: Qt.size(84, 84); anchors.verticalCenter: parent.verticalCenter
                    source: root.cur ? root.iconOf(root.cur.class) : "" }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.cur ? root.cur.title : ""
                width: Math.min(implicitWidth, root.width * 0.5); elide: Text.ElideRight
                font.family: Appearance.font.family; font.pixelSize: 24; font.weight: Font.DemiBold
                color: Appearance.colors.fg
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Repeater {
                model: root.cur ? [root.cur.class, "espace " + root.cur.workspace.id, root.cur.floating ? "flottante" : "", (view.currentIndex + 1) + " / " + root.wins.length].filter(x => x !== "") : []
                Rectangle {
                    required property string modelData
                    required property int index
                    height: 30; width: chip.implicitWidth + 24; radius: 15
                    color: index === 1 ? ColorUtils.applyAlpha(root.glow, 0.85) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                    Text { id: chip; anchors.centerIn: parent; text: parent.modelData
                           font.family: Appearance.font.family; font.pixelSize: 13
                           color: parent.index === 1 ? Appearance.textOn(root.glow) : Appearance.colors.fg }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Tab  ·  Maj+Tab  ·  ←→  ·  relâcher Alt pour y aller  ·  Échap"
            font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim
        }
    }
}
