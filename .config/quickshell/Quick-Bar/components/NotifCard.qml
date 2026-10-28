import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.core
import qs.core.functions
import qs.services

// NotifCard — une notification, même aspect que les menus Quick-Bar (verre, arrondi relié à la barre,
// contour animé selon le thème). Utilisée par les toasts (panels/NotifToasts.qml) et le centre
// (panels/NotifCenter.qml). `progress` (1 → 0) : temps restant d'un toast.
Item {
    id: card
    required property var notif
    property real progress: -1             // < 0 : pas de barre de temps
    property bool compact: false           // centre : corps sur 2 lignes
    property bool animatedBorder: true     // contour dégradé animé (toasts) ; fixe dans le centre (beaucoup de cartes)
    signal closeRequested()

    readonly property bool critical: notif && notif.urgency === NotificationUrgency.Critical
    readonly property color glow: critical ? Qt.lighter(Appearance.colors.color1, 1.6)
                                : Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                  ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent
    // arrondi proportionnel à celui de la barre (comme les menus)
    readonly property real radRatio: Appearance.bar.maxRadius > 0 ? Math.max(0, Math.min(1, Appearance.bar.radius / Appearance.bar.maxRadius)) : 0.5
    function rad(h) { return Math.min(radRatio * h / 2, 12 + radRatio * 20) }
    readonly property bool hovered: hov.hovered
    readonly property var acts: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    readonly property var defAct: notif ? notif.actions.find(a => a.identifier === "default") : null
    readonly property bool device: !!notif && notif.appName === "Périphériques"
    readonly property string iconSrc: {
        if (!notif) return ""
        const i = notif.image || notif.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.startsWith("file:") || i.startsWith("image:") || i.startsWith("data:")) return i
        return i ? Quickshell.iconPath(i, true) : ""
    }

    implicitWidth: 420
    implicitHeight: col.implicitHeight + 28

    HoverHandler { id: hov }

    RectangularShadow { anchors.fill: parent; anchors.topMargin: 10; radius: box.radius; blur: 26; color: ColorUtils.applyAlpha("#000000", 0.55) }
    ClippingRectangle {
        id: box
        anchors.fill: parent
        radius: card.rad(Math.min(height, 120))
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96)
        border.width: card.animatedBorder && Appearance.animationsEnabled && !card.critical ? 0 : (card.animatedBorder || card.critical ? 2 : 1)
        border.color: ColorUtils.applyAlpha(card.glow, card.animatedBorder || card.critical ? 0.8 : 0.3)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, card.hovered ? 0.09 : 0.06) }
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 1.0; color: ColorUtils.applyAlpha("#000000", 0.18) }
            }
        }
        Rectangle { x: box.radius; width: parent.width - box.radius * 2; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.14) }
        // temps restant
        Rectangle {
            visible: card.progress >= 0
            anchors.bottom: parent.bottom
            height: 3; width: parent.width * Math.max(0, card.progress)
            color: ColorUtils.applyAlpha(card.glow, 0.85)
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: card.defAct ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) { card.notif.dismiss(); return }
                if (card.defAct) card.defAct.invoke()
                card.closeRequested()
            }
        }

        Column {
            id: col
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            Row {
                width: parent.width
                spacing: 12
                // icône ou image de l'application ; photo de périphérique (services/Batteries.qml) en grand,
                // entière, sur une lueur d'accent
                ClippingRectangle {
                    readonly property int side: card.device ? 76 : 46
                    width: side; height: side; radius: card.device ? side / 2 : card.rad(46)
                    color: card.device ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.16) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                    visible: card.iconSrc !== ""
                    Image { anchors.fill: parent; anchors.margins: card.device ? 8 : 0
                            source: card.iconSrc
                            fillMode: card.device ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            sourceSize: Qt.size(152, 152); asynchronous: true }
                }
                Column {
                    width: parent.width - (card.iconSrc !== "" ? (card.device ? 88 : 58) : 0) - 26
                    spacing: 3
                    Row {
                        spacing: 8
                        Text { text: card.notif ? (card.notif.appName || "Notification") : ""
                               font.family: Appearance.font.family; font.pixelSize: 11; font.letterSpacing: 1
                               color: card.glow }
                        Text { text: card.notif ? "· " + NotificationService.ago(card.notif) : ""
                               font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                    }
                    Text {
                        width: parent.width
                        text: card.notif ? card.notif.summary : ""
                        elide: Text.ElideRight; textFormat: Text.PlainText
                        font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                        color: Appearance.colors.fg
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.notif ? card.notif.body : ""
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap; maximumLineCount: card.compact ? 2 : 4; elide: Text.ElideRight
                        font.family: Appearance.font.family; font.pixelSize: 13
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.75)
                        onLinkActivated: (l) => Qt.openUrlExternally(l)
                    }
                }
            }
            // actions
            Row {
                visible: card.acts.length > 0
                spacing: 8
                Repeater {
                    model: card.acts
                    Rectangle {
                        required property var modelData
                        height: 32; width: aT.implicitWidth + 28; radius: card.rad(32)
                        color: aMa.containsMouse ? ColorUtils.applyAlpha(card.glow, 0.85) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                        border.width: 1; border.color: ColorUtils.applyAlpha(card.glow, 0.5)
                        Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                        Text { id: aT; anchors.centerIn: parent; text: parent.modelData.text
                               font.family: Appearance.font.family; font.pixelSize: 13
                               color: aMa.containsMouse ? Appearance.textOn(card.glow) : Appearance.colors.fg }
                        MouseArea { id: aMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { parent.modelData.invoke(); card.closeRequested() } }
                    }
                }
            }
        }
        // fermer
        Rectangle {
            anchors { top: parent.top; right: parent.right; margins: 10 }
            width: 26; height: 26; radius: 13
            opacity: card.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Appearance.dur(150) } }
            color: xMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.15) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
            Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg }
            MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.notif.dismiss() }
        }
    }
    GradientBorder {
        anchors.fill: box; radius: box.radius; borderWidth: 2
        visible: card.animatedBorder && Appearance.animationsEnabled && !card.critical
    }
}
