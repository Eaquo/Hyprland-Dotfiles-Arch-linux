import QtQuick
import "." as T
import Quickshell.Io
import Quickshell.Widgets
import qs.core
import qs.core.functions

// Files — liste de fichiers avec aperçu à droite (image ou début du texte).
// Le chemin vient de la métadonnée `path`, sinon de `id`, sinon du texte.
T.List {
    id: f
    prefW: 1180
    hints: "↑↓ choisir  ·  maj+↑↓ ou molette : défiler l'aperçu  ·  entrée ouvrir"
    function scrollPreview(d) { flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + d * 120)) }
    rows: 11
    minRows: 11
    listW: width * 0.46
    readonly property var it: menu.items[menu.cur] || null
    readonly property string path: { const p = it ? (it.path || it.id || it.t) : ""; return p.startsWith("/") ? p : "" }
    readonly property bool isImg: /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path)
    onPathChanged: { prev.text = ""; if (path && !isImg) { cat.command = ["sh", "-c", 'case "$1" in *.txt|*.md|*.log) head -c 60000 "$1" ;; *) file -b "$1" | grep -qi text && head -c 60000 "$1" || file -b "$1" ;; esac', "_", path]; cat.running = true } }
    Process { id: cat; stdout: StdioCollector { onStreamFinished: prev.text = text } }

    ClippingRectangle {
        x: 14; width: parent.width - 14; height: parent.height
        radius: f.menu.rad(height)
        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
        Image {
            anchors.fill: parent; anchors.margins: 10
            visible: f.isImg
            source: f.isImg ? "file://" + f.path : ""
            fillMode: Image.PreserveAspectFit; asynchronous: true
            sourceSize: Qt.size(900, 900)
        }
        // aperçu défilable : molette, ou Maj+↑/↓ au clavier
        Flickable {
            id: flick
            visible: !f.isImg
            anchors.fill: parent; anchors.margins: 14; anchors.bottomMargin: 34
            contentWidth: prev.implicitWidth; contentHeight: prev.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Behavior on contentY { NumberAnimation { duration: Appearance.dur(140); easing.type: Easing.OutCubic } }
            Text {
                id: prev
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                color: Appearance.colors.fg; opacity: 0.85
                wrapMode: Text.NoWrap; textFormat: Text.PlainText
                onTextChanged: flick.contentY = 0
            }
        }
        Rectangle {   // barre de défilement
            visible: !f.isImg && flick.contentHeight > flick.height
            x: parent.width - 8; y: flick.y + flick.visibleArea.yPosition * flick.height
            width: 4; height: Math.max(24, flick.visibleArea.heightRatio * flick.height); radius: 2
            color: ColorUtils.applyAlpha(f.menu.glow, 0.6)
        }
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            text: f.it && f.it.sub ? f.it.sub : f.path; elide: Text.ElideMiddle   // sub : un libellé à la place du chemin
            font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim
        }
    }
}
