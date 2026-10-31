import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions
import qs.services
import qs.pages.eq

// EqCenter — centre audio flottant au milieu de l'écran principal (clic droit sur le volume ou le micro de la
// barre, Popups.eqCenterOpen) : la page EQ complète (pages/eq/EqDash.qml : presets, 10 bandes, spectre,
// volume et sortie) + un volet d'options : micro, volume par appli, sortie suivante, pavucontrol, EasyEffects.
// Fond assombri : toucher à côté ou Échap ferme.
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => !Config.isTouch(s)) || Quickshell.screens[0]
    color: "transparent"
    visible: windowVisible
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:eqcenter"
    WlrLayershell.keyboardFocus: windowVisible && Popups.eqCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool windowVisible: false

    // ── Profils audio : sortie + preset EQ d'un toucher ([[audio.profiles]] dans config.toml :
    //    name, icon, sink = motif cherché dans le nom de la sortie, preset = preset EQ d'eq_control.py) ──
    readonly property var profiles: Config.get("audio.profiles", [
        { name: "Casque Bose", icon: "󰋋", sink: "bose|wax|bluez", preset: "Bose-Music" },
        { name: "KZ · Scarlett", icon: "󰟎", sink: "scarlett", preset: "KZ-HIFI" }
    ])
    function sinkFor(p) {
        const re = new RegExp(p.sink || "^$", "i")
        return Mixer.outputs.find(n => re.test([n.name, n.description, n.nickname].join(" "))) || null
    }
    Process { id: presetProc }
    function applyProfile(p) {
        const s = sinkFor(p)
        if (!s) return
        Mixer.setOutput(s)
        if (p.preset) { presetProc.command = ["python3", Quickshell.shellDir + "/scripts/audio/eq_control.py", "load_preset", p.preset]
                        presetProc.running = false; presetProc.running = true }
    }
    property real p: 0                                  // ouverture 0 → 1
    Behavior on p { NumberAnimation { duration: Appearance.dur(Popups.eqCenterOpen ? 420 : 260); easing.type: Easing.OutCubic } }
    Connections {
        target: Popups
        function onEqCenterOpenChanged() {
            if (Popups.eqCenterOpen) { closeTimer.stop(); root.windowVisible = true; root.p = 1; keys.forceActiveFocus() }
            else { root.p = 0; closeTimer.restart() }
        }
    }
    Component.onCompleted: if (Popups.eqCenterOpen) { windowVisible = true; p = 1 }
    Timer { id: closeTimer; interval: Appearance.dur(280); onTriggered: root.windowVisible = false }

    Item { id: keys; focus: true; Keys.onEscapePressed: Popups.eqCenterOpen = false }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.applyAlpha("#000000", 0.45 * root.p)
        MouseArea { anchors.fill: parent; onClicked: Popups.eqCenterOpen = false }
    }

    // ── carte centrale ──
    ClippingRectangle {
        id: card
        width: Math.min(root.width - 120, 1560); height: Math.min(root.height - 160, 760)
        anchors.centerIn: parent
        radius: 26
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.35)
        opacity: root.p
        scale: 0.92 + 0.08 * root.p
        transform: Translate { y: (1 - root.p) * 30 }
        MouseArea { anchors.fill: parent }             // absorbe : ne ferme pas

        Item {
            anchors { fill: parent; margins: 22 }

            Loader {                                    // la page EQ complète du dashboard
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: sep.left; rightMargin: 22 }
                active: root.windowVisible
                sourceComponent: EqDash {}
            }
            Rectangle { id: sep; anchors { top: parent.top; bottom: parent.bottom; right: opts.left; rightMargin: 22 }
                        width: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) }

            // ── Options ──
            ColumnLayout {
                id: opts
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 360
                spacing: 14

                Text { text: "PROFILS"; font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold
                       font.letterSpacing: 2; color: Appearance.colors.dim }
                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                    Repeater {
                        model: root.profiles
                        delegate: Rectangle {
                            id: prof
                            required property var modelData
                            readonly property var sink: root.sinkFor(modelData)
                            readonly property bool on: !!sink && sink === Mixer.sink
                            Layout.fillWidth: true; implicitHeight: 64; radius: 16
                            opacity: sink ? 1 : 0.45
                            color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.25)
                                      : ColorUtils.applyAlpha(Appearance.colors.fg, pMa.containsMouse ? 0.1 : 0.05)
                            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, on ? 0.9 : 0.2)
                            Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 10
                                Text { anchors.verticalCenter: parent.verticalCenter; text: prof.modelData.icon || "󰋋"
                                       font.family: Appearance.font.family; font.pixelSize: 24; color: Appearance.colors.accent }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: prof.modelData.name; font.family: Appearance.font.family; font.pixelSize: 14
                                           font.weight: Font.DemiBold; color: Appearance.colors.fg }
                                    Text { text: prof.sink ? "EQ " + prof.modelData.preset : "non connecté"
                                           font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                                }
                            }
                            MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; enabled: !!prof.sink
                                        cursorShape: Qt.PointingHandCursor; onClicked: root.applyProfile(prof.modelData) }
                        }
                    }
                }

                Text { text: "MICRO"; font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold
                       font.letterSpacing: 2; color: Appearance.colors.dim }
                VolRow { node: Mixer.source; label: Mixer.source ? Mixer.deviceName(Mixer.source) : "—"; glyph: "󰍬"; mutedGlyph: "󰍭" }

                Text { Layout.topMargin: 8; text: "APPLICATIONS"; font.family: Appearance.font.family; font.pixelSize: 12
                       font.weight: Font.Bold; font.letterSpacing: 2; color: Appearance.colors.dim }
                Flickable {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentHeight: appsCol.implicitHeight; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: appsCol
                        width: parent.width; spacing: 10
                        Repeater {
                            model: Mixer.apps
                            delegate: VolRow { required property var modelData; nodes: modelData.nodes; label: modelData.label
                                               icon: Mixer.icon(modelData.nodes[0]) }
                        }
                        Text { visible: Mixer.apps.length === 0; text: "aucune appli ne joue de son"
                               font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim }
                    }
                }

                // actions
                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                    Action { glyph: "󰓃"; text: "Sortie suivante"; onTap: Mixer.cycleOutput() }
                    Action { glyph: "󰕾"; text: "Pavucontrol"; onTap: { Quickshell.execDetached(["pavucontrol"]); Popups.eqCenterOpen = false } }
                    Action { glyph: "󰺢"; text: "EasyEffects"; onTap: { Quickshell.execDetached(["easyeffects"]); Popups.eqCenterOpen = false } }
                    Action { glyph: "󰅖"; text: "Fermer"; onTap: Popups.eqCenterOpen = false }
                }
            }
        }
        GradientBorder { anchors.fill: parent; radius: card.radius; borderWidth: 2; opacity: 0.6 }
    }

    // ── une ligne de volume : icône (muet au clic), nom, curseur, % ; molette = ±5 % ──
    component VolRow: RowLayout {
        id: vr
        property var node: null
        property var nodes: node ? [node] : []
        property string label: ""
        property string icon: ""
        property string glyph: "󰕾"
        property string mutedGlyph: "󰖁"
        readonly property var audio: nodes.length ? nodes[0]?.audio : null
        readonly property real vol: audio ? audio.volume : 0
        readonly property bool muted: audio ? audio.muted : false
        Layout.fillWidth: true
        spacing: 10
        Item {
            Layout.preferredWidth: 30; Layout.preferredHeight: 30
            Image { anchors.fill: parent; visible: vr.icon !== ""; source: vr.icon; sourceSize: Qt.size(60, 60); opacity: vr.muted ? 0.4 : 1 }
            Text { anchors.centerIn: parent; visible: vr.icon === ""; text: vr.muted ? vr.mutedGlyph : vr.glyph
                   font.family: Appearance.font.family; font.pixelSize: 20; color: vr.muted ? Appearance.colors.color13 : Appearance.colors.accent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Mixer.toggleMute(vr.nodes) }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: vr.label
                   font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.fg }
            Rectangle {
                id: track
                Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                Rectangle { height: parent.height; radius: 4; width: parent.width * Math.min(1, vr.vol)
                            color: vr.muted ? Appearance.colors.dim : Appearance.colors.accent }
                MouseArea {
                    anchors { fill: parent; topMargin: -10; bottomMargin: -10 }
                    cursorShape: Qt.PointingHandCursor
                    function set(x) { Mixer.setVolume(vr.nodes, Math.max(0, Math.min(1, x / track.width))) }
                    onPressed: (m) => set(m.x)
                    onPositionChanged: (m) => { if (pressed) set(m.x) }
                    onWheel: (w) => Mixer.setVolume(vr.nodes, vr.vol + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }
        Text { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: Math.round(vr.vol * 100) + "%"
               font.family: Appearance.font.family; font.pixelSize: 13; color: vr.muted ? Appearance.colors.dim : Appearance.colors.accent }
    }

    component Action: Rectangle {
        id: act
        property string glyph
        property string text
        signal tap()
        Layout.fillWidth: true; implicitHeight: 44; radius: 12
        color: aMa.pressed ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.3) : ColorUtils.applyAlpha(Appearance.colors.fg, aMa.containsMouse ? 0.1 : 0.05)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.2)
        Row { anchors.centerIn: parent; spacing: 8
              Text { text: act.glyph; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.accent }
              Text { text: act.text; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.fg } }
        MouseArea { id: aMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: act.tap() }
    }
}
