import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Common/"

Item {
    id: root

    property bool active: false

    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    Process {
        id: checkProc
        command: ["bash", "-c", "pgrep -x localsend > /dev/null && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "1"
        }
    }

    Process {
        id: launchProc
        command: ["bash", "-c", "setsid /usr/bin/localsend &"]
        onRunningChanged: if (!running) Qt.callLater(() => refreshTimer.start())
    }

    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow", "class:localsend"]
    }

    Process {
        id: killProc
        command: ["pkill", "-x", "localsend"]
        onRunningChanged: if (!running) Qt.callLater(() => refreshTimer.start())
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    Timer {
        id: refreshTimer
        interval: 1200; repeat: false
        onTriggered: checkProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (ev) => {
            if (ev.button === Qt.RightButton) {
                killProc.running = true
            } else {
                if (root.active) focusProc.running = true
                else             launchProc.running = true
            }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Image {
            id: lsIcon
            source: Qt.resolvedUrl("../../assets/icons/localsend.svg")
            width:  Appearance.bar.height - 12
            height: Appearance.bar.height - 12
            smooth: true
            opacity: root.active ? 1.0 : 0.35

            layer.enabled: true
            layer.effect: MultiEffect {
                colorization:      1.0
                colorizationColor: Appearance.colors.color15
            }

            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // pulse dot when active
        Rectangle {
            width:  5
            height: 5
            radius: width / 2
            visible: root.active
            color: Appearance.colors.color4

            SequentialAnimation on opacity {
                running: root.active
                loops: Animation.Infinite
                NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }
    }
}
