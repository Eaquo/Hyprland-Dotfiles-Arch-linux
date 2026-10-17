import QtQuick
import qs.core

Text {
    id: root
    property bool extended: false

    function update() {
        var d  = new Date()
        text = "    " + d.toLocaleString(Qt.locale("fr_FR"), Config.get("bar.clock_format", "HH:mm:ss"))
    }

    color: Appearance.colors.color15
    font.pixelSize: 14
    font.family: "Cascadia Code"

    Component.onCompleted: {
        var pos = root.mapToGlobal(root.implicitWidth / 2, 0)
        Appearance.calPopupX = pos.x
    }

    Timer {
        // chaque seconde seulement si le format les affiche
        interval: String(Config.get("bar.clock_format", "HH:mm:ss")).includes("s") ? 1000 : 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.update()
    }

    Connections { target: Config; function onDataChanged() { root.update() } }

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
