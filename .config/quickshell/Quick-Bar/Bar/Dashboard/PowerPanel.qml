import QtQuick
import "../Common/"
import "../Components/"

Item {
    id: root

    required property var cpuFreqService

    Column {
        anchors.centerIn: parent
        spacing:          16

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            // Label + lock icon hinting auto-cpufreq manages this
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Text {
                    text:           "󰌾"
                    font.pixelSize: 11
                    color:          Qt.rgba(1, 1, 1, 0.25)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text:           "Power Profile"
                    font.pixelSize: 11
                    font.weight:    Font.Medium
                    color:          Qt.rgba(1, 1, 1, 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                ProfileButton {
                    label:     root.cpuFreqService.activeProfile === "performance" ? "Performance" : "Power Saver"
                    active:    true
                    enabled:   true
                }
            }
        }

    }
}
