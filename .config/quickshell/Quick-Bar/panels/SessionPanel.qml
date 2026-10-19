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

// SessionPanel — verrouiller, veille, déconnexion, redémarrer, éteindre, BIOS
// (CTRL+ALT+P, bouton ⏻ de la barre, `qs ipc call session toggle`).
// [session] style : "matrix" (SessionMatrix.qml) et "minimal" (SessionMinimal.qml) en plein écran,
// "card" = carte centrée qui s'ouvre goutte → pilule → déroulé, contour en dégradé. Éteindre / redémarrer / déconnexion / BIOS : une jauge se remplit 3 s avant
// d'agir (Échap ou clic pour annuler) — pas de fenêtre de confirmation.
//   ←/→ choisir · Entrée valider · l u e r s b raccourcis directs · Échap fermer / annuler
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
    WlrLayershell.namespace: "quickshell:session"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.sessionOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // style : plein écran "matrix" (pluie + terminal), "minimal" (grande heure), "cyber" (netrunner, breach protocol),
    // "jarvis" (HUD) — ou "card" (carte centrée)
    readonly property string style: String(Config.get("session.style", "matrix"))
    readonly property bool isCard: !["matrix", "minimal", "cyber", "jarvis"].includes(style)

    // ── Actions ───────────────────────────────────────────────────────────
    // [clé, icône, libellé, touche, couleur (slot palette), confirmation, commande]
    readonly property var actions: [
        ["lock",     "󰌾", "Verrouiller", "l", 12, false, ["loginctl", "lock-session"]],
        ["suspend",  "󰤄", "Veille",      "u", 14, false, ["systemctl", "suspend"]],
        ["logout",   "󰍃", "Déconnexion", "e", 11, true,  ["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\" || hyprctl dispatch exit"]],
        ["reboot",   "󰜉", "Redémarrer",  "r", 13, true,  ["systemctl", "reboot"]],
        ["shutdown", "󰐥", "Éteindre",    "s", 1,  true,  ["systemctl", "poweroff"]],
        ["bios",     "󰘚", "BIOS",        "b", 10, true,  ["systemctl", "reboot", "--firmware-setup"]]
    ]
    property int sel: 0
    property string armed: ""            // action en compte à rebours
    property real armT: 0                // 0 → 1 pendant le compte à rebours
    // actions sans retour en rouge, les autres à l'accent
    function tint(i) {
        const c = actions[i][5] ? Appearance.colors.color1 : Appearance.colors.accent
        return Appearance.contrastRatio(c, Appearance.colors.bg) < 3.5 ? Qt.lighter(c, 1.7) : c   // lisible sur le fond
    }
    function trigger(i) {
        const a = actions[i]
        sel = i
        if (armed === a[0]) { cancel(); return }           // 2e appui = annuler
        if (a[5]) { armed = a[0]; armAnim.restart(); return }
        run(a)
    }
    function cancel() { armAnim.stop(); armed = ""; armT = 0 }
    function run(a) {
        armed = ""
        cmd.command = a[6]
        Popups.sessionOpen = false
        // laisser la fermeture se jouer (sauf veille/verrou, attendus tout de suite)
        later.interval = a[0] === "lock" || a[0] === "suspend" ? Appearance.dur(250) : Appearance.dur(500)
        later.restart()
    }
    Process { id: cmd }
    Timer { id: later; onTriggered: cmd.running = true }
    NumberAnimation {
        id: armAnim
        target: root; property: "armT"; from: 0; to: 1; duration: 3000
        onFinished: { const a = root.actions.find(x => x[0] === root.armed); if (a) root.run(a) }
    }

    // ── Ouverture / fermeture ─────────────────────────────────────────────
    property bool windowVisible: false
    property real intro: 0
    // créé par un LazyLoader (shell.qml) quand on l'ouvre, détruit après la fermeture : aucune RAM fermé
    Component.onCompleted: { if (Popups.sessionOpen) openConn.onSessionOpenChanged() }
    Connections {
        id: openConn
        target: Popups
        function onSessionOpenChanged() {
            if (Popups.sessionOpen) {
                closeTimer.stop(); root.windowVisible = true; root.cancel(); root.sel = 0
                uptimeProc.running = true; keys.forceActiveFocus()
                if (root.isCard) { outAnim.stop(); inAnim.restart() }
                else if (full.item) full.item.open()
            } else {
                root.cancel()
                if (root.isCard) { inAnim.stop(); outAnim.restart() }
                else if (full.item) full.item.close()
                closeTimer.interval = root.isCard || !full.item ? Appearance.dur(700) + 40 : full.item.outMs + 40
                closeTimer.restart()
            }
        }
    }
    // ouverture : ligne → pilule → déroulé (comme les Réglages et le sélecteur de fond)
    // état de départ = fermé (le panneau est créé à l'ouverture : sinon 1re image en grand, puis l'animation)
    property real mw: 2
    property real mh: 2
    readonly property real fullW: Math.min(1080, width - 120)
    readonly property real fullH: 400
    SequentialAnimation {
        id: inAnim
        ScriptAction { script: { root.mw = 2; root.mh = 2; root.intro = 0 } }
        NumberAnimation { target: root; property: "mw"; to: root.fullW * 0.7; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(280); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: root; property: "mw"; to: root.fullW; duration: Appearance.dur(280); easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: root.fullH; duration: Appearance.dur(440); easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(200) }
                NumberAnimation { target: root; property: "intro"; to: 1; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: { root.mw = Qt.binding(() => root.fullW); root.mh = Qt.binding(() => root.fullH) } }
    }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: Appearance.dur(140) }
        NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(280); easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mw"; to: 2; duration: Appearance.dur(240); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "mh"; to: 2; duration: Appearance.dur(240); easing.type: Easing.InCubic }
        }
    }
    Timer { id: closeTimer; interval: Appearance.dur(700) + 40; onTriggered: root.windowVisible = false }

    // commandes IPC : dans shell.qml (le panneau n'existe que lorsqu'il est ouvert)

    // ── Clavier ───────────────────────────────────────────────────────────
    Item {
        id: keys
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { if (root.armed !== "") root.cancel(); else Popups.sessionOpen = false }
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up)  { root.cancel(); root.sel = (root.sel + root.actions.length - 1) % root.actions.length }
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.cancel(); root.sel = (root.sel + 1) % root.actions.length }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.trigger(root.sel)
            else {
                const i = root.actions.findIndex(a => a[3] === e.text.toLowerCase())
                if (i < 0) return
                root.trigger(i)
            }
            e.accepted = true
        }
    }

    // ── Voile : clic à côté = fermer (ou annuler un compte à rebours) ─────
    Rectangle {
        anchors.fill: parent
        visible: root.isCard
        color: "#000000"
        opacity: Popups.sessionOpen ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(260) } }
        MouseArea { anchors.fill: parent; onClicked: { if (root.armed !== "") root.cancel(); else Popups.sessionOpen = false } }
    }

    // ── Horloge, salutation, durée d'allumage ─────────────────────────────
    property var now: new Date()
    Timer { interval: 1000; running: root.windowVisible; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    property string uptime: ""
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        stdout: StdioCollector { onStreamFinished: root.uptime = text.trim()
            .replace(/weeks?/, "sem.").replace(/days?/, "j").replace(/hours?/, "h").replace(/minutes?/, "min") }
    }
    readonly property string greeting: { const h = now.getHours(); return h < 5 ? "Bonne nuit" : h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir" }

    // ── Halo flouté autour de la carte (comme SUPER+W) : accent, rouge pendant un compte à rebours ──
    Rectangle {
        id: halo
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius
        color: root.armed !== "" ? Appearance.colors.color1 : Appearance.colors.accent
        Behavior on color { ColorAnimation { duration: Appearance.dur(300) } }
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        visible: root.isCard
        source: halo
        x: halo.x; y: halo.y; width: halo.width; height: halo.height
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.6
        opacity: 0.5 * root.intro
        autoPaddingEnabled: true
    }

    // ── La carte ──────────────────────────────────────────────────────────
    ClippingRectangle {
        id: box
        visible: root.isCard
        x: (root.width - root.mw) / 2
        y: (root.height - root.mh) / 2
        width: root.mw; height: root.mh
        radius: Math.min(Appearance.cornerRadius, height / 2)
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.97)
        MouseArea { anchors.fill: parent }

        Item {
            x: (root.mw - root.fullW) / 2; y: (root.mh - root.fullH) / 2
            width: root.fullW; height: root.fullH
            opacity: root.intro
            transform: Translate { y: (1 - root.intro) * 10 }

            ColumnLayout {
                anchors { fill: parent; margins: 26 }
                spacing: 20

                // en-tête : avatar, salutation, heure
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ClippingRectangle {
                        Layout.preferredWidth: 60; Layout.preferredHeight: 60
                        radius: 30
                        color: Appearance.colors.color0
                        border.width: 2; border.color: Appearance.colors.accent
                        Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + Config.avatar; fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(120, 120); asynchronous: true }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: root.greeting + ", " + Config.userName
                               font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold; color: Appearance.colors.fg }
                        Text {
                            readonly property string day: root.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM")
                            text: day.charAt(0).toUpperCase() + day.slice(1) + (root.uptime ? "  ·  allumé depuis " + root.uptime : "")
                            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.dim
                        }
                    }
                    Text { text: Qt.formatTime(root.now, "HH:mm")
                           font.family: Appearance.font.family; font.pixelSize: 44; font.weight: Font.Bold; color: Appearance.colors.accent }
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 32; height: 32; radius: 10
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, xMa.containsMouse ? 0.12 : 0.05)
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg }
                        MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Popups.sessionOpen = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) }

                // les actions, en tuiles
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    Repeater {
                        model: root.actions
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool isSel: root.sel === index
                            readonly property bool isArmed: root.armed === modelData[0]
                            readonly property color col: root.tint(index)
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 14
                            color: isArmed ? ColorUtils.applyAlpha(col, 0.18)
                                 : isSel ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.14)
                                 : tMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.07) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.035)
                            border.width: isSel || isArmed ? 2 : 1
                            border.color: isArmed ? col : isSel ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                            Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
                            scale: tMa.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: Appearance.dur(110) } }

                            // halo de l'icône de la tuile sélectionnée
                            Rectangle {
                                id: tGlow
                                x: tCol.x + tIcon.x + tIcon.width / 2 - width / 2
                                y: tCol.y + tIcon.y + tIcon.height / 2 - height / 2
                                width: 70; height: 70; radius: 35
                                color: tile.isArmed ? tile.col : Appearance.colors.accent
                                visible: false; layer.enabled: true
                            }
                            MultiEffect {
                                anchors.fill: tGlow; source: tGlow
                                blurEnabled: true; blur: 1; blurMax: 40
                                opacity: tile.isSel || tile.isArmed ? 0.45 : 0
                                Behavior on opacity { NumberAnimation { duration: Appearance.dur(220) } }
                            }
                            ColumnLayout {
                                id: tCol
                                anchors.centerIn: parent
                                spacing: 10
                                Text { id: tIcon; Layout.alignment: Qt.AlignHCenter; text: tile.modelData[1]
                                       font.family: Appearance.font.family; font.pixelSize: 38
                                       color: tile.isArmed ? tile.col : tile.isSel ? Appearance.colors.accent : Appearance.colors.fg }
                                Text { Layout.alignment: Qt.AlignHCenter
                                       text: tile.isArmed ? tile.modelData[2] + " dans " + Math.ceil(3 - root.armT * 3) + "…" : tile.modelData[2]
                                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; font.weight: Font.DemiBold
                                       color: tile.isArmed ? tile.col : Appearance.colors.fg }
                                Text { Layout.alignment: Qt.AlignHCenter
                                       text: tile.isArmed ? "Échap pour annuler" : tile.modelData[3].toUpperCase()
                                       font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim }
                            }
                            // jauge du compte à rebours
                            Rectangle {
                                visible: tile.isArmed
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
                                height: 4; radius: 2
                                color: ColorUtils.applyAlpha(tile.col, 0.2)
                                Rectangle { width: parent.width * root.armT; height: parent.height; radius: 2; color: tile.col }
                            }
                            MouseArea {
                                id: tMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: if (root.armed === "") root.sel = tile.index
                                onClicked: root.trigger(tile.index)
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "←→ choisir  ·  Entrée valider  ·  L U E R S B  ·  Échap fermer"
                    font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim
                }
            }
        }
    }

    // contour en dégradé animé, comme les autres panneaux
    GradientBorder {
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius
        borderWidth: 2
        visible: root.isCard && Appearance.animationsEnabled && root.windowVisible
    }
    Rectangle {
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius; color: "transparent"
        border.width: 2; border.color: Appearance.outline
        visible: root.isCard && !Appearance.animationsEnabled && root.windowVisible
    }

    // ── Styles plein écran ────────────────────────────────────────────────
    Loader {
        id: full
        anchors.fill: parent
        active: !root.isCard && root.windowVisible
        sourceComponent: ({ minimal: minimalC, cyber: cyberC, jarvis: jarvisC })[root.style] || matrixC
        onLoaded: if (Popups.sessionOpen) item.open()
    }
    Component { id: matrixC; SessionMatrix { p: root } }
    Component { id: minimalC; SessionMinimal { p: root } }
    Component { id: cyberC; SessionCyber { p: root } }
    Component { id: jarvisC; SessionJarvis { p: root } }
}
