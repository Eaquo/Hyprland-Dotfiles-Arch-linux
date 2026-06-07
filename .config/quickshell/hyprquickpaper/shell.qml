import Quickshell
import Quickshell.Io // for Process
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland



PanelWindow {
    id: main
    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    property int speed: 5000

    property color wallustAccent: (wallust.colors && wallust.colors["color5"]) ? wallust.colors["color5"] : configs.border_color
    property color bgColor: (wallust.special && wallust.special["background"]) ? wallust.special["background"] : "#0f0f0f"

    // Animated border color — updated from image sampling
    property color borderColor: main.wallustAccent
    Behavior on borderColor {
        ColorAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])
        console.log(Quickshell.shellDir)
    }

    // Dominant color extractor from thumbnail
    Canvas {
        id: colorSampler
        width: 16
        height: 16
        visible: false

        property string pendingSource: ""

        function sample(source) {
            if (pendingSource === source) return
            pendingSource = source
            loadImage(source)
        }

        onImageLoaded: requestPaint()

        onPaint: {
            if (!pendingSource) return
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(pendingSource, 0, 0, width, height)
            var d = ctx.getImageData(0, 0, width, height).data

            var bestR = 128, bestG = 128, bestB = 128, bestScore = -1
            for (var i = 0; i < d.length; i += 4) {
                var r = d[i], g = d[i+1], b = d[i+2]
                var max = Math.max(r, g, b)
                var min = Math.min(r, g, b)
                var sat = max === 0 ? 0 : (max - min) / max
                var bright = max / 255
                // Favor vivid + bright colors, avoid near-black
                var score = sat * (0.4 + 0.6 * bright)
                if (score > bestScore) {
                    bestScore = score
                    bestR = r; bestG = g; bestB = b
                }
            }
            main.borderColor = Qt.rgba(bestR/255, bestG/255, bestB/255, 1)
        }
    }

    FileView {
        path: "/home/florian/.cache/wallust/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: wallust
            property var special
            property var colors
        }
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    // Panel background
    Rectangle {
        anchors.fill: parent
        color: main.bgColor
        opacity: 0.88
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png","*.jpg"]
        sortField: FolderListModel.Name
    }

    ListView {
        id: list
        anchors.fill: parent
        focus: true

        model: folderModel
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        cacheBuffer: width * 2

        property int selectedIndex: 0
        property real tileWidth: width / configs.number_of_pictures - 10

        onSelectedIndexChanged: {
            const fileName = folderModel.get(selectedIndex, "fileName")
            if (fileName)
                colorSampler.sample("file://" + configs.cache_path + fileName)
        }

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1))
        }

        function activateCurrent() {
            const path = folderModel.get(selectedIndex, "filePath")
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path])
            Qt.quit()
        }

        function clampX(x) {
            return Math.max(0, Math.min(x, contentWidth - width))
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing
            const itemStart = i * step
            const itemEnd = itemStart + tileWidth + 20

            if (itemStart < contentX)
                contentX = clampX(itemStart)
            else if (itemEnd > contentX + width)
                contentX = clampX(itemStart - (width - step))
        }

        Behavior on contentX {
            SmoothedAnimation {
                id: anim
                property int v: 10
                duration: 100
            }
        }
        Component.onCompleted:{
            anim.v = main.speed
        }


        delegate: Item {
            property bool active: index === list.selectedIndex
            width: list.tileWidth
            height: 500

            Behavior on width{
                NumberAnimation {
                    duration: 50
                    easing.type: Easing.OutCubic
                }
            }

            Text{
                id: alt
                text: "Loading..."
                color: main.borderColor
                anchors.centerIn: parent
                font.pixelSize: 16
                transform: Shear { xFactor: -0.25 }
            }

            Image {
                id: img
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: false
                smooth: true

                source: "file://" + configs.cache_path + fileName

                sourceSize.width: width
                sourceSize.height: height

                opacity: status === Image.Ready ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                transform: Shear { xFactor: -0.25 }

                Timer {
                    id: retryTimer
                    interval: 1000
                    repeat: false
                    onTriggered: {
                        let s = img.source
                        img.source = ""
                        img.source = s
                    }
                }

                onStatusChanged: {
                    if (status === Image.Error) {
                        alt.text = "Caching"
                        retryTimer.start()
                    }
                }
            }

            // Gradient overlay at bottom (active only)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 80
                visible: parent.active
                transform: Shear { xFactor: -0.25 }

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }

            // Filename label on active tile
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 10
                visible: parent.active && img.status === Image.Ready
                text: fileName.substring(0, fileName.lastIndexOf('.')) || fileName
                color: main.borderColor
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                width: list.tileWidth - 20
                horizontalAlignment: Text.AlignHCenter
                transform: Shear { xFactor: -0.25 }
            }

            // Selection border
            Rectangle {
                id: border
                z: 10
                visible: parent.active
                width: list.tileWidth
                height: 500
                color: "transparent"

                border.width: 3
                border.color: main.borderColor

                transform: Shear { xFactor: -0.25 }
            }

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    list.selectedIndex = index
                    list.activateCurrent()
                }

                onWheel: function(wheel) {
                    anim.v = main.speed
                    const delta = wheel.angleDelta.y > 0 ? -1 : 1
                    list.selectedIndex = list.clampIndex(list.selectedIndex + delta)
                    list.ensureVisibleAnimated(list.selectedIndex)
                    wheel.accepted = true
                }
            }
        }

        Keys.onPressed: function(event) {
            const step = 1
            const big = configs.number_of_pictures

            if (event.key === Qt.Key_J) {
                anim.v = main.speed
                selectedIndex = clampIndex(selectedIndex + step)
                ensureVisibleAnimated(selectedIndex)

            } else if (event.key === Qt.Key_K) {
                anim.v = main.speed
                selectedIndex = clampIndex(selectedIndex - step)
                ensureVisibleAnimated(selectedIndex)

            } else if (event.key === Qt.Key_D) {
                anim.v = main.speed * big
                selectedIndex = clampIndex(selectedIndex + big)
                ensureVisibleAnimated(selectedIndex)

            } else if (event.key === Qt.Key_U) {
                anim.v = main.speed * big
                selectedIndex = clampIndex(selectedIndex - big)
                ensureVisibleAnimated(selectedIndex)

            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                activateCurrent()

            } else if (event.key === Qt.Key_Escape) {
                Qt.quit()

            } else return

            event.accepted = true
        }
    }
}
