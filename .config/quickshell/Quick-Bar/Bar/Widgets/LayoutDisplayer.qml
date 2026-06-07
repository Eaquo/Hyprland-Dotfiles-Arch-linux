import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Common/"

// ─── LayoutDisplayer ────────────────────────────────────────────────────────
//   Clic gauche  → cycle le layout suivant
//   Clic droit   → déploie la liste des layouts (survol = nom du bouton)
//   Molette      → (layouts mono-fenêtre) change la fenêtre focus  [1] → [2]
// ────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    property bool expanded: false

    implicitWidth:  expanded ? selRow.implicitWidth + 8 : 26
    implicitHeight: 26
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // ── State ────────────────────────────────────────────────────────────────
    property string configProvider: ShellState.configProvider
    property string currentLayout: ""
    property string numWindows: ""
    property int    focusIndex: 0      // rang de la fenêtre focus dans le WS
    property int    winCount:   0
    property var availableLayouts: ["dwindle", "master", "monocle", "scrolling", "hy3"]

    // Layouts « mono-fenêtre » → molette pour changer la fenêtre + index entre []
    readonly property bool singleView: currentLayout === "scrolling" || currentLayout === "monocle"

    // Symbole de l'icône repliée
    function layoutSymbol(name) {
        var i = root.focusIndex > 0 ? root.focusIndex : root.numWindows
        switch (name.toLowerCase()) {
            case "dwindle":   return "><"
            case "master":    return "M"
            case "monocle":   return "|"+i+"|"
            case "scrolling": return "["+i+"]"
            case "hy3":       return "H3"
            default:          return "?"
        }
    }

    // Badge court (sélecteur) + nom complet (survol)
    function layoutBadge(name) {
        switch (name) {
            case "dwindle":   return "><"
            case "master":    return "M"
            case "monocle":   return "□"
            case "scrolling": return "<>"
            case "hy3":       return "H3"
            default:          return "?"
        }
    }
    function layoutName(name) {
        switch (name) {
            case "dwindle":   return "Dwindle"
            case "master":    return "Master"
            case "monocle":   return "Monocle"
            case "scrolling": return "Scrolling"
            case "hy3":       return "Hy3"
            default:          return name
        }
    }

    // ── Requêtes hyprctl ───────────────────────────────────────────────────────
    Process {
        id: queryProc
        command: ["hyprctl", "-j", "activeworkspace"]
        running: false
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                try {
                    const obj = JSON.parse(collector.text)
                    if (obj && obj.tiledLayout) {
                        root.currentLayout = obj.tiledLayout.toLowerCase()
                        root.numWindows = obj.windows > 0 ? obj.windows.toString() : "  "
                    }
                } catch (e) {}
            }
        }
    }

    // Index de la fenêtre focus + nombre de fenêtres du workspace
    Process {
        id: idxProc
        command: ["sh", "-c",
            "ws=$(hyprctl -j activeworkspace | jq '.id'); " +
            "aw=$(hyprctl -j activewindow | jq -r '.address // \"\"'); " +
            "hyprctl -j clients | jq -r --argjson ws \"$ws\" --arg aw \"$aw\" " +
            "'[.[]|select(.workspace.id==$ws and .mapped==true)]|sort_by(.at[0],.at[1]) as $w" +
            "|($w|length) as $n|(([$w|to_entries[]|select(.value.address==$aw)|.key][0] // -1)+1) as $i" +
            "|\"\\($i) \\($n)\"'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/)
                if (p.length >= 2) {
                    root.focusIndex = parseInt(p[0]) || 0
                    root.winCount   = parseInt(p[1]) || 0
                }
            }
        }
    }

    function refresh() {
        if (!queryProc.running) queryProc.running = true
        idxProc.running = false; idxProc.running = true
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) { root.refresh() }
    }

    Timer {
        interval: 4000; running: true; repeat: true
        onTriggered: root.refresh()
    }

    // ── Changement de layout (config lua) ───────────────────────────────────────
    Process { id: setLayoutProc; running: false }
    function setLayout(name) {
        if (root.configProvider === "lua")
            setLayoutProc.command = ["hyprctl", "eval", `hl.config({ general = { layout = "${name}" } })`]
        else
            setLayoutProc.command = ["hyprctl", "keyword", "general:layout", name]
        setLayoutProc.running = true
        root.currentLayout = name
    }
    function cycleLayout(step) {
        let idx = availableLayouts.indexOf(root.currentLayout)
        if (idx === -1) idx = 0
        idx = (idx + step + availableLayouts.length) % availableLayouts.length
        setLayout(availableLayouts[idx])
    }

    // ── Changement de fenêtre focus (molette) ───────────────────────────────────
    Process { id: cycleProc; running: false }
    property bool wheelBusy: false
    Timer { id: wheelCd; interval: 140; onTriggered: root.wheelBusy = false }
    function cycleWindow(prev) {
        if (root.wheelBusy) return
        root.wheelBusy = true; wheelCd.restart()
        var arg = prev ? "{ prev = true }" : "{}"
        cycleProc.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.window.cycle_next(" + arg + "))"]
        cycleProc.running = false; cycleProc.running = true
    }

    // ── Tout flotter en grille ───────────────────────────────────────────────────
    Process { id: floatGridProc; running: false }
    function floatGrid() {
        floatGridProc.command = ["sh",
            Qt.resolvedUrl("../Scripts/float_grid.sh").toString().replace("file://", "")]
        floatGridProc.running = true
    }

    // ── Repli auto quand la souris quitte ───────────────────────────────────────
    HoverHandler { id: rootHov }
    Timer {
        id: collapseTimer
        interval: 1200; repeat: false
        running: root.expanded && !rootHov.hovered
        onTriggered: root.expanded = false
    }

    // ── Icône repliée ───────────────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        visible: !root.expanded
        color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton)       root.cycleLayout(1)
                else if (mouse.button === Qt.RightButton) root.expanded = true
            }
        }

        // Molette → change la fenêtre focus (layouts mono-fenêtre)
        WheelHandler {
            enabled: root.singleView
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => root.cycleWindow(event.angleDelta.y > 0)
        }

        Text {
            id: icon
            anchors.centerIn: parent
            text: root.currentLayout !== "" ? root.layoutSymbol(root.currentLayout) : "…"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: "#cdd6f4"

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: icon; property: "scale"; to: 0.6; duration: 80;  easing.type: Easing.InQuad }
                    NumberAnimation { target: icon; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack }
                }
            }
        }
    }

    // ── Sélecteur déployé ───────────────────────────────────────────────────────
    Row {
        id: selRow
        anchors.centerIn: parent
        visible: root.expanded
        spacing: 3

        // Pastille générique avec révélation du nom au survol
        component ActionPill: Rectangle {
            id: ap
            property string badge: ""
            property string label: ""
            property bool   active: false
            signal activated()

            height: 22; radius: 5
            width: apHov.hovered ? apTxt.implicitWidth + 16 : 24
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            color: ap.active ? Appearance.colors.accent
                 : (apHov.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.05))
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: apTxt
                anchors.centerIn: parent
                text: apHov.hovered ? ap.label : ap.badge
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: apHov.hovered ? 10 : 12
                color: ap.active ? Appearance.colors.bg : "#cdd6f4"
            }
            HoverHandler { id: apHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    if (m.button === Qt.RightButton) { root.expanded = false; return }
                    ap.activated()
                }
            }
        }

        // Un layout par pastille
        Repeater {
            model: root.availableLayouts
            delegate: ActionPill {
                required property string modelData
                badge:  root.layoutBadge(modelData)
                label:  root.layoutName(modelData)
                active: modelData === root.currentLayout
                onActivated: { root.setLayout(modelData); root.expanded = false }
            }
        }

        // Séparateur
        Rectangle {
            width: 1; height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.15)
        }

        // Action : tout flotter en grille
        ActionPill {
            badge: "▦"
            label: "Float grid"
            onActivated: { root.floatGrid(); root.expanded = false }
        }
    }
}
