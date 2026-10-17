import QtQuick
import Quickshell.Widgets
import qs.core
import qs.core.functions

// MorphCard — carte qui s'ouvre comme les cartes de survol de la barre :
// une goutte tombe, s'étire en pilule, puis se déroule et le contenu apparaît.
// play() rejoue l'ouverture (avec un délai de `order` × 70 ms pour les cascades).
// Le contenu (enfants) est posé dans une zone pleine taille de contentHeight.
Item {
    id: card
    property int order: 0
    property real contentHeight: 100              // hauteur de la carte ouverte
    property bool hot: false                      // contour mis en avant (survol, appui)
    property color hotColor: Appearance.colors.accent
    default property alias content: inner.data
    function play() { enter.restart() }

    implicitHeight: contentHeight
    readonly property real dot: 26
    property real w: width
    property real h: contentHeight
    property real by: 0
    property real shown: 1

    SequentialAnimation {
        id: enter
        ScriptAction { script: { card.w = card.dot; card.h = card.dot; card.shown = 0; card.by = -card.dot } }
        PauseAnimation { duration: Appearance.dur(70 * card.order) }
        NumberAnimation { target: card; property: "by"; to: 0; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "w"; to: card.width; duration: Appearance.dur(360); easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: card; property: "h"; to: card.contentHeight; duration: Appearance.dur(500); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(200) }
                NumberAnimation { target: card; property: "shown"; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: { card.w = Qt.binding(() => card.width); card.h = Qt.binding(() => card.contentHeight) } }
    }

    ClippingRectangle {
        x: (card.width - card.w) / 2
        y: card.by
        width: card.w; height: card.h
        radius: Math.min(16, Math.min(width, height) / 2)
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
        border.width: 1
        border.color: card.hot ? ColorUtils.applyAlpha(card.hotColor, 0.7) : ColorUtils.applyAlpha(Appearance.colors.color15, 0.22)
        Behavior on border.color { ColorAnimation { duration: Appearance.dur(160) } }

        Item {
            id: inner
            x: (card.w - card.width) / 2
            width: card.width; height: card.contentHeight
            opacity: card.shown
            transform: Translate { y: (1 - card.shown) * 8 }
        }
    }
}
