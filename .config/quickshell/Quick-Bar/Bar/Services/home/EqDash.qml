import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../Common/"
import "../../Common/functions/"
import "../../Components/"
import "../"

// EqDash — page Equalizer du dashboard, en 3 blocs :
//   1. Zone du haut : titre + presets + reset + Now Playing + spectre live
//   2. Égaliseur    : preamp + échelle dB + 10 bandes
//   3. Volume       : volume maître + périphérique de sortie

Item {
    id: root

    // ── State EQ ────────────────────────────────────────────────────────────
    property var    gains:         [0,0,0,0,0,0,0,0,0,0]
    property string currentPreset: ""
    property real   preamp:        0
    readonly property var freqLabels: ["32","64","125","250","500","1k","2k","4k","8k","16k"]
    readonly property string scriptPath:
        Qt.resolvedUrl("../../Scripts/eq_control.py").toString().replace("file://", "")

    function setGain(idx, val) {
        var arr = root.gains.slice()
        arr[idx] = Math.round(val * 2) / 2
        root.gains = arr
        applyTimer.restart()
    }

    function applyGains() {
        var args = ["python3", root.scriptPath, "set_gains"]
        for (var i = 0; i < 10; i++) args.push(root.gains[i].toFixed(1))
        setGainsProc.command = args
        setGainsProc.running = true
    }

    // Preamp : décale toutes les bandes (le backend n'a pas de preamp natif)
    function applyPreamp(newVal) {
        var v     = Math.max(-12, Math.min(12, Math.round(newVal * 2) / 2))
        var delta = v - root.preamp
        root.preamp = v
        if (delta === 0) return
        var arr = root.gains.slice()
        for (var i = 0; i < 10; i++)
            arr[i] = Math.max(-12, Math.min(12, Math.round((arr[i] + delta) * 2) / 2))
        root.gains = arr
        applyTimer.restart()
    }

    function resetAll() {
        root.preamp = 0
        root.gains  = [0,0,0,0,0,0,0,0,0,0]
        applyGains()
    }


    // ── Processes EQ ────────────────────────────────────────────────────────
    Process {
        id: getProc
        command: ["python3", root.scriptPath, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    root.gains         = d.gains
                    root.currentPreset = d.preset
                } catch(e) {}
            }
        }
    }
    Process { id: setGainsProc }
    Process {
        id: loadPresetProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    if (d.gains)  root.gains         = d.gains
                    if (d.preset) root.currentPreset = d.preset
                } catch(e) {}
            }
        }
    }
    Timer {
        id: applyTimer
        interval: 250; repeat: false
        onTriggered: root.applyGains()
    }
    Component.onCompleted: getProc.running = true
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) getProc.running = true
        }
    }

    // ── Audio (PipeWire) ──────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property var sinkNodes: {
        var out = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && n.isSink) out.push(n)
        }
        return out
    }
    function deviceName(n) { return n.nickname || n.description || n.name || "—" }
    function cycleOutput() {
        var l = root.sinkNodes
        if (l.length < 2) return
        var ci = 0
        for (var i = 0; i < l.length; i++)
            if (root.sink && l[i].name === root.sink.name) ci = i
        Pipewire.preferredDefaultAudioSink = l[(ci + 1) % l.length]
    }

    // ── Slider vertical réutilisable ──────────────────────────────────────────
    component GainSlider: Item {
        id: gs
        property real    value:       0     // -12 .. +12
        property string  bottomLabel: ""
        property int     trackH:      150
        signal moved(real v)
        signal resetReq()

        width:  30
        height: trackH + 38

        function gainAt(my) {
            var ratio = 1.0 - Math.max(0, Math.min(gs.trackH, my)) / gs.trackH
            return Math.max(-12.0, Math.min(12.0, ratio * 24.0 - 12.0))
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
            text: gs.value === 0 ? "·" : (gs.value > 0 ? "+" : "") + gs.value.toFixed(1)
            font.pixelSize: 10
            font.family:    Appearance.font.family
            color: gs.value > 0 ? Appearance.colors.accent
                 : gs.value < 0 ? Appearance.colors.red
                 : ColorUtils.applyAlpha(Appearance.colors.fg, 0.20)
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Rectangle {
            id: gsTrack
            width: 6; height: gs.trackH
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
            radius: 3
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)

            Rectangle {
                visible: gs.value > 0
                width: parent.width; radius: parent.radius
                height: Math.max(0, (gs.value / 12.0) * (gsTrack.height / 2))
                y: gsTrack.height / 2 - height
                color: Appearance.colors.accent; opacity: 0.85
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                Behavior on y      { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                visible: gs.value < 0
                width: parent.width; radius: parent.radius
                height: Math.max(0, (-gs.value / 12.0) * (gsTrack.height / 2))
                y: gsTrack.height / 2
                color: Appearance.colors.red; opacity: 0.75
                Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: gsTrack.height / 2 - 1
                width: 10; height: 1
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.22)
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.horizontalCenter: parent.horizontalCenter
                y: (1.0 - (gs.value + 12.0) / 24.0) * (gsTrack.height - height)
                color: Math.abs(gs.value) < 0.1
                    ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.45)
                    : Appearance.colors.accent
                Rectangle {
                    anchors { top: parent.top; topMargin: 2; horizontalCenter: parent.horizontalCenter }
                    width: parent.width - 6; height: 3; radius: 1.5
                    color: ColorUtils.applyAlpha("#ffffff", 0.25)
                }
                Behavior on y     { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 120 } }
            }
        }

        MouseArea {
            x: gsTrack.x - 12; y: gsTrack.y
            width: 30; height: gsTrack.height
            cursorShape: Qt.SizeVerCursor
            onPressed:       (ev) => gs.moved(gs.gainAt(ev.y))
            onMouseYChanged: if (pressed) gs.moved(gs.gainAt(mouseY))
            onDoubleClicked: gs.resetReq()
            onWheel: (ev) => {
                var step = ev.modifiers & Qt.ShiftModifier ? 0.1 : 0.5
                gs.moved(gs.value + (ev.angleDelta.y > 0 ? step : -step))
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            text: gs.bottomLabel
            font.pixelSize: 10
            font.family:    Appearance.font.family
            color: Appearance.colors.dim
        }
    }

    // ── Visual : 3 blocs empilés, même largeur, centrés ───────────────────────
    ColumnLayout {
        id: blocks
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 8

        // ── Bloc 1 : zone du haut (fond = jaquette du morceau) ────────────
        StatCard {
            Layout.fillWidth: true
            Layout.preferredHeight: topCol.implicitHeight + padding * 2
            padding: 18
            artPath: Appearance.mediaArtPath

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                spacing: 14

                // Titre + presets + reset
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Rectangle { width: 7; height: 7; radius: 3.5; color: Appearance.colors.accent }
                    Text {
                        text: "Equalizer"
                        font.family:    Appearance.font.family
                        font.pixelSize: Appearance.font.body
                        font.weight:    Font.Medium
                        color:          Appearance.colors.fg
                    }

                    Item { Layout.fillWidth: true; implicitWidth: 30 }

                    Repeater {
                        model: ["HP", "Bose", "Flat"]
                        Rectangle {
                            required property string modelData
                            property bool active: root.currentPreset === modelData
                            implicitWidth:  pLbl.implicitWidth + 22
                            implicitHeight: 26
                            radius: 13
                            color: active ? Appearance.colors.accent
                                          : ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                            border.color: active ? "transparent"
                                                 : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                id: pLbl
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.pixelSize: Appearance.font.small - 1
                                font.family:    Appearance.font.family
                                font.weight:    Font.Medium
                                color: parent.active ? Appearance.colors.color8 : Appearance.colors.color10
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    loadPresetProc.command = ["python3", root.scriptPath, "load_preset", parent.modelData]
                                    loadPresetProc.running = true
                                    root.currentPreset     = parent.modelData
                                    root.preamp            = 0
                                }
                            }
                        }
                    }

                    // Reset
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: rstHov.hovered ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) : "transparent"
                        border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰜉"
                            font.family:    Appearance.font.family
                            font.pixelSize: 13
                            color: rstHov.hovered ? Appearance.colors.fg : Appearance.colors.dim
                        }
                        HoverHandler { id: rstHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: root.resetAll() }
                    }
                }

                // Now Playing
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        width: 38; height: 38
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            visible: Appearance.mediaArtPath === ""
                            color:        ColorUtils.applyAlpha(Appearance.colors.accent, 0.18)
                            border.width: 1
                            border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.38)
                            Text {
                                anchors.centerIn: parent
                                text: "♪"; font.pixelSize: 18; color: Appearance.colors.accent
                            }
                        }
                        Rectangle { id: npMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                        Image {
                            anchors.fill: parent
                            source:  Appearance.mediaArtPath !== "" ? ("file://" + Appearance.mediaArtPath) : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth:   true
                            visible:  Appearance.mediaArtPath !== ""
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true; maskSource: npMask
                                maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            width: parent.width
                            text: Appearance.mediaStatus !== "Stopped" && Appearance.mediaTitle !== ""
                                  ? Appearance.mediaTitle : "Aucune lecture"
                            elide: Text.ElideRight
                            font.family:    Appearance.font.family
                            font.pixelSize: Appearance.font.small
                            font.weight:    Font.Medium
                            color: Appearance.colors.fg
                        }
                        Text {
                            width: parent.width
                            visible: Appearance.mediaArtist !== ""
                            text: Appearance.mediaArtist
                            elide: Text.ElideRight
                            font.family:    Appearance.font.family
                            font.pixelSize: Appearance.font.small - 2
                            color: Appearance.colors.dim
                        }
                    }
                }

                // Spectre live (CavaService) — agrandi + étalé sur la largeur
                Item {
                    id: spectre
                    Layout.fillWidth: true
                    implicitHeight: 80
                    opacity: CavaService.isPlaying ? 1 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    readonly property int bw: 6

                    Row {
                        anchors.fill: parent
                        spacing: Math.max(2, (width - CavaService.barCount * spectre.bw)
                                              / Math.max(1, CavaService.barCount - 1))
                        Repeater {
                            model: CavaService.barCount
                            Item {
                                id: sBar
                                required property int index
                                property real lvl: CavaService.bars.length > index
                                    ? CavaService.bars[index] / 100.0 : 0.0
                                width:  spectre.bw
                                height: spectre.height
                                Rectangle {
                                    anchors.centerIn: parent
                                    width:  spectre.bw
                                    height: Math.max(spectre.bw, parent.height * sBar.lvl)
                                    radius: width / 2
                                    color: Appearance.specColor(sBar.index / CavaService.barCount + Appearance.specPhase)
                                    opacity: 0.30 + 0.70 * sBar.lvl
                                    Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Bloc 2 : l'égaliseur (preamp + dB + bandes) ───────────────────
        StatCard {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            padding: 18

            RowLayout {
                id: slidersRow
                anchors.fill: parent
                spacing: 20

                // hauteur de piste = hauteur dispo - (texte gain + label)
                readonly property int trkH: Math.max(80, height - 38)

                // Preamp
                GainSlider {
                    Layout.alignment: Qt.AlignTop
                    trackH: slidersRow.trkH
                    value: root.preamp
                    bottomLabel: "Pre"
                    onMoved:    (v) => root.applyPreamp(v)
                    onResetReq: root.applyPreamp(0)
                }

                // Séparateur
                Rectangle {
                    implicitWidth: 1; implicitHeight: slidersRow.trkH
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 14
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                }

                // Échelle dB
                Item {
                    implicitWidth: 26
                    implicitHeight: slidersRow.trkH
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 14
                    Repeater {
                        model: 5
                        Text {
                            required property int modelData
                            anchors.right: parent.right
                            y: (modelData / 4.0) * slidersRow.trkH - implicitHeight / 2
                            text: { var db = 12 - modelData * 6; return db > 0 ? "+" + db : String(db) }
                            font.pixelSize: 9
                            font.family:    Appearance.font.family
                            color: (12 - modelData * 6) === 0
                                ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.40)
                                : Appearance.colors.dim
                        }
                    }
                }

                // Bandes — réparties sur la largeur restante
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    Row {
                        width: parent.width
                        spacing: Math.max(6, (width - 10 * 30) / 9)
                        Repeater {
                            model: 10
                            GainSlider {
                                id: bandSlider
                                required property int index
                                trackH: slidersRow.trkH
                                value: root.gains.length > index ? root.gains[index] : 0.0
                                bottomLabel: root.freqLabels[index]
                                onMoved:    (v) => root.setGain(index, v)
                                onResetReq: root.setGain(index, 0.0)
                            }
                        }
                    }
                }
            }
        }

        // ── Bloc 3 : volume + sortie audio ────────────────────────────────
        StatCard {
            Layout.fillWidth: true
            Layout.preferredHeight: volRow.implicitHeight + padding * 2
            padding: 16

            RowLayout {
                id: volRow
                anchors.fill: parent
                spacing: 12

                Text {
                    text: {
                        if (!root.sink?.ready)            return "󰖁"
                        if (root.sink.audio.muted)         return "󰖁"
                        if (root.sink.audio.volume > 0.6)  return "󰕾"
                        if (root.sink.audio.volume > 0.2)  return "󰖀"
                        return "󰕿"
                    }
                    font.family:    Appearance.font.family
                    font.pixelSize: 16
                    color: (root.sink?.ready && root.sink.audio.muted)
                        ? Appearance.colors.red : Appearance.colors.accent
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
                    }
                }

                Item {
                    id: volSlider
                    Layout.fillWidth: true
                    implicitHeight: 18
                    readonly property real val: root.sink?.ready ? root.sink.audio.volume : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 5; radius: 2.5
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.10)
                        Rectangle {
                            width: parent.width * volSlider.val; height: parent.height; radius: parent.radius
                            color: Appearance.colors.accent
                        }
                    }
                    Rectangle {
                        width: 13; height: 13; radius: 6.5; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width - width) * volSlider.val
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setv(mx) {
                            var v = Math.max(0, Math.min(1, mx / width))
                            if (root.sink?.ready) root.sink.audio.volume = v
                        }
                        onPressed:         (ev) => setv(ev.x)
                        onPositionChanged: if (pressed) setv(mouseX)
                    }
                    WheelHandler {
                        onWheel: function(ev) {
                            if (!root.sink?.ready) return
                            var step = 0.05
                            root.sink.audio.volume = Math.max(0, Math.min(1,
                                root.sink.audio.volume + (ev.angleDelta.y > 0 ? step : -step)))
                        }
                    }
                }

                Text {
                    text: root.sink?.ready ? Math.round(root.sink.audio.volume * 100) + "%" : "--%"
                    font.family:    Appearance.font.family
                    font.pixelSize: Appearance.font.small - 1
                    color: Appearance.colors.fg
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 38
                }

                // Périphérique de sortie (clic = suivant)
                Rectangle {
                    implicitWidth: devRow.implicitWidth + 18
                    implicitHeight: 26
                    radius: 13
                    color: devHov.hovered ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.10)
                                          : ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        id: devRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰓃"
                            font.family: Appearance.font.family
                            font.pixelSize: 12
                            color: Appearance.colors.dim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.sink?.ready ? root.deviceName(root.sink) : "—"
                            font.family:    Appearance.font.family
                            font.pixelSize: Appearance.font.small - 2
                            color: Appearance.colors.fg
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 160)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    HoverHandler { id: devHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.cycleOutput() }
                }
            }
        }
    }
}
