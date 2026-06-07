import QtQuick
import "../Common/"

Text {
    id: root
    property bool extended: false

    function update() {
        var d  = new Date()
        var fr = Qt.locale("fr_FR")
        text = "    " + Qt.formatTime(d, "HH:mm:ss")
    }

    color: Appearance.colors.color15
    font.pixelSize: 14
    font.family: "Cascadia Code"

    Component.onCompleted: {
        var pos = root.mapToGlobal(root.implicitWidth / 2, 0)
        Appearance.calPopupX = pos.x
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.update()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        z: 10
        onClicked: {
            var next = !Popups.dashboardOpen
            Popups.closeAll()
            Popups.dashboardOpen = next
        }
    }
}
