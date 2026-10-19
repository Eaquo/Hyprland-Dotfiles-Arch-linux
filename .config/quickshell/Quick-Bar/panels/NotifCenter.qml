import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions
import qs.services

// NotifCenter — l'historique des notifications (SUPER+MAJ+N, clic sur le module de la barre), dans
// l'esprit du panneau Spotify : il naît du bord de l'écran (trait, demi-sphère, déroulé, élargissement).
// Regroupées par application ; « Ne pas déranger », « Tout effacer ». Créé à l'ouverture, détruit après
// (LazyLoader dans shell.qml). [notifications] width (460).
PanelWindow {
    id: root

    readonly property int fw: Appearance.notchRadius
    readonly property int fh: Appearance.notchRadius
    readonly property int animDuration: Appearance.animDuration
    readonly property int panelWidth:  Config.get("notifications.width", 460)
    // presque toute la hauteur, sous la barre si elle est en haut ou en bas
    readonly property int panelHeight: Math.round((screen?.height ?? 1440) - (Appearance.bar.vertical ? 0 : Appearance.bar.thickness) - 2 * fh - 60)
    // Toujours du côté opposé à la barre : à gauche quand la barre est à droite
    readonly property bool onLeft: Appearance.bar.position === "right"

    // Écran principal = tout sauf le tactile Xeneon.
    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }

    color:   "transparent"
    visible: windowVisible
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell:notifcenter"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.notifCenterOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool windowVisible: false
    // créé par un LazyLoader (shell.qml) quand on l'ouvre, détruit après la fermeture : aucune RAM fermé
    Component.onCompleted: { if (Popups.notifCenterOpen) openConn.onNotifCenterOpenChanged() }
    Connections {
        id: openConn
        target: Popups
        function onNotifCenterOpenChanged() {
            if (Popups.notifCenterOpen) { closeTimer.stop(); root.windowVisible = true; keys.forceActiveFocus(); slideTimer.restart() }
            else { slideTimer.stop(); root.slid = false; closeTimer.restart() }
        }
    }
    // Le glissement ne démarre qu'une fois la fenêtre affichée (sa création prend
    // quelques dizaines de ms) : sinon le début de l'animation est perdu.
    property bool slid: false
    Timer { id: slideTimer; interval: 60; onTriggered: root.slid = true }
    // La fenêtre reste affichée le temps de l'animation de fermeture (reveal.closeAnim)
    Timer { id: closeTimer; interval: 1550; onTriggered: root.windowVisible = false }

    // commandes IPC : dans shell.qml (le panneau n'existe que lorsqu'il est ouvert)

    // ── Notifications, regroupées par application (la plus récente d'abord) ──
    readonly property color glow: Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                  ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent
    readonly property real radRatio: Appearance.bar.maxRadius > 0 ? Math.max(0, Math.min(1, Appearance.bar.radius / Appearance.bar.maxRadius)) : 0.5
    function rad(h) { return Math.min(radRatio * h / 2, 12 + radRatio * 20) }
    readonly property var groups: {
        const order = [], map = {}
        for (const n of NotificationService.list) {
            const k = n.appName || "Notifications"
            if (!map[k]) { map[k] = []; order.push(k) }
            map[k].push(n)
        }
        return order.map(k => ({ app: k, items: map[k] }))
    }

    // Clic à côté = fermer
    MouseArea { anchors.fill: parent; onClicked: Popups.notifCenterOpen = false }

    Item {
        id: sizer
        // Bande pleine hauteur (pour le trait du bord droit) ; le panneau lui-même
        // garde sa taille et reste centré dedans : [bodyY, bodyY + bodyH].
        anchors { top: parent.top; bottom: parent.bottom
                  right: root.onLeft ? undefined : parent.right; left: root.onLeft ? parent.left : undefined }
        width: root.panelWidth
        clip: true
        // Côté gauche : toute la forme (trait du bord, raccords, animation) est retournée en miroir ;
        // le contenu est retourné une 2e fois pour rester lisible.
        transform: Scale { origin.x: sizer.width / 2; xScale: root.onLeft ? -1 : 1 }
        readonly property real bodyH: root.panelHeight + 2 * root.fh
        // Centré sur la hauteur de l'ÉCRAN, pas de la fenêtre : celle-ci vaut 0 un
        // instant à chaque ouverture, ce qui faisait arriver le panneau en diagonale.
        readonly property real bodyY: Math.round(((root.screen?.height ?? height) - bodyH) / 2)

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: Popups.notifCenterOpen = false
        }

        // Ouverture — la forme animée est une vraie PopupShape (trait du bord + raccords
        // creux + corps, d'un seul tracé), donc toujours rattachée au bord comme le panneau fini :
        //   1. le trait du bord droit pousse depuis le centre vers le haut et le bas
        //   2. une demi-sphère naît contre ce trait, déjà raccordée par ses arrondis creux
        //   3. elle s'étire à la verticale, moitié vers le haut, moitié vers le bas
        //   4. elle s'élargit vers la gauche jusqu'aux dimensions exactes du panneau,
        //      puis le contenu apparaît ; le vrai panneau (identique) prend le relais
        // Fermeture : le même chemin à l'envers, jusqu'au trait qui se rétracte au centre.
        //
        // morphFill (dessous) : fond de la forme, raccords compris
        // reveal (milieu)     : découpe le vrai panneau + son contenu à la taille du corps
        // morphLine (dessus)  : bordure en dégradé de la forme
        component MorphShape: PopupShape {
            x: root.panelWidth - Math.max(reveal.rw, 2)
            width: Math.max(reveal.rw, 2)
            y: reveal.cy - reveal.lineH / 2
            height: Math.max(reveal.lineH, 1)
            attachedEdge: "right-full"
            bodyY:      reveal.cy - reveal.rh / 2 - flareHeight - y
            bodyHeight: reveal.rh + 2 * flareHeight
            // le corps doit loger l'arrondi ET le raccord : rayon ≤ largeur − raccord
            flareWidth:  Math.min(root.fw * reveal.flare, width)
            radius:      Math.max(0, Math.min(reveal.mr, reveal.rh / 2, reveal.rw - flareWidth))
            flareHeight: root.fh * reveal.flare
            opacity: reveal.lineOp
            visible: opacity > 0.01 && reveal.lineH > 0.5
        }
        MorphShape {
            id: morphFill
            color: Appearance.background
        }

        ClippingRectangle {
            id: reveal
            readonly property real cy: sizer.bodyY + sizer.bodyH / 2
            readonly property real dot: 34
            // Hauteur de l'ÉCRAN : la fenêtre vaut 0 un instant à l'ouverture (cf. sizer.bodyY)
            readonly property real fullH: root.screen?.height ?? sizer.height
            // Corps du panneau sans ses raccords : le déroulé s'arrête là
            readonly property real bodyH: root.panelHeight
            // état de départ = fermé (le panneau est créé à l'ouverture) ; finish() pose l'état final
            property real rw: 0                     // largeur du corps, comptée depuis le bord droit
            property real rh: 0                     // hauteur du corps
            property real mr: 0                     // rayon des coins de gauche
            property real flare: 0                  // taille des raccords creux (0 → 1)
            property real content: 0
            property real lineH: 0                  // longueur du trait du bord droit
            property real lineOp: 1                 // opacité de la forme animée (0 = vrai panneau)
            property bool done: false               // animation finie : plus de découpe
            // État final (aussi appliqué si l'animation est interrompue)
            function finish() {
                rw = Qt.binding(() => root.panelWidth); rh = Qt.binding(() => bodyH)
                mr = Appearance.cornerRadius; flare = 1; content = 1
                lineH = Qt.binding(() => fullH); done = true
            }
            // pendant l'animation : découpe au corps (le côté droit dépasse, hors écran) ;
            // ensuite : toute la bande, pour laisser voir les raccords du vrai panneau
            x: done ? 0 : root.panelWidth - rw
            y: done ? 0 : cy - rh / 2
            width: done ? root.panelWidth : rw + mr
            height: done ? fullH : rh
            radius: done ? 0 : Math.min(mr, rh / 2)
            color: "transparent"

            Connections {
                target: root
                function onSlidChanged() {
                    if (root.slid) { closeAnim.stop(); openAnim.restart() }
                    else { openAnim.stop(); closeAnim.restart() }
                }
            }
            SequentialAnimation {
                id: openAnim
                ScriptAction { script: {
                    reveal.done = false
                    reveal.rw = 0; reveal.rh = 0; reveal.mr = 0; reveal.flare = 0; reveal.content = 0
                    reveal.lineH = 0; reveal.lineOp = 1
                } }
                // 1. le trait du bord pousse depuis le centre
                NumberAnimation { target: reveal; property: "lineH"; to: reveal.fullH; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
                // 2. la demi-sphère naît, raccordée au trait
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: reveal.dot + root.fw; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "rh"; to: reveal.dot * 2; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "mr"; to: reveal.dot; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "flare"; to: 1; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                }
                // 3. déroulé vertical, centré (50 % en haut, 50 % en bas)
                NumberAnimation { target: reveal; property: "rh"; to: reveal.bodyH; duration: Appearance.dur(480); easing.type: Easing.OutCubic }
                // 4. élargissement vers la gauche, coins qui prennent le rayon du panneau
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: root.panelWidth; duration: Appearance.dur(460); easing.type: Easing.OutCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: Appearance.cornerRadius; duration: Appearance.dur(460); easing.type: Easing.InOutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: Appearance.dur(200) }
                        NumberAnimation { target: reveal; property: "content"; to: 1; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                    }
                }
                ScriptAction { script: reveal.finish() }
                // le vrai panneau, identique, prend le relais de la forme animée
                NumberAnimation { target: reveal; property: "lineOp"; to: 0; duration: Appearance.dur(220) }
            }
            // Fermeture : le chemin inverse
            SequentialAnimation {
                id: closeAnim
                ScriptAction { script: {
                    reveal.lineOp = 1; reveal.rw = root.panelWidth; reveal.rh = reveal.bodyH
                    reveal.mr = Appearance.cornerRadius; reveal.flare = 1; reveal.lineH = reveal.fullH
                    reveal.done = false
                } }
                NumberAnimation { target: reveal; property: "content"; to: 0; duration: Appearance.dur(180); easing.type: Easing.InCubic }
                // 4⁻¹. resserrement vers le bord, coins qui s'arrondissent en demi-sphère
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: reveal.dot + root.fw; duration: Appearance.dur(360); easing.type: Easing.InOutCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: reveal.dot; duration: Appearance.dur(360); easing.type: Easing.OutCubic }
                }
                // 3⁻¹. la bande se replie en demi-sphère
                NumberAnimation { target: reveal; property: "rh"; to: reveal.dot * 2; duration: Appearance.dur(380); easing.type: Easing.InOutCubic }
                // 2⁻¹. la demi-sphère rentre dans le trait
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InBack; easing.overshoot: 1.4 }
                    NumberAnimation { target: reveal; property: "rh"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                    NumberAnimation { target: reveal; property: "flare"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                }
                // 1⁻¹. le trait se rétracte vers le centre
                NumberAnimation { target: reveal; property: "lineH"; to: 0; duration: Appearance.dur(300); easing.type: Easing.InCubic }
            }

        // Corps du panneau, pleine taille, recalé sous la zone révélée
        Item {
            x: -reveal.x
            y: -reveal.y
            width: root.panelWidth
            height: reveal.fullH

            // Absorbe les clics sur le panneau seulement (au-dessus/en dessous,
            // un clic ferme comme partout ailleurs).
            MouseArea { y: sizer.bodyY; width: parent.width; height: sizer.bodyH }

            PopupShape {
                anchors.fill: parent
                attachedEdge: "right-full"
                bodyY:        sizer.bodyY
                bodyHeight:   sizer.bodyH
                color:        Appearance.background
                radius:       Appearance.cornerRadius
                flareWidth:   root.fw
                flareHeight:  root.fh
                borderColor:    Appearance.outline
                // masquée pendant l'animation : le contour animé la dessine à la même place,
                // elle ne revient qu'à la fin (une seule ligne visible à tout moment)
                borderWidth:    reveal.content >= 0.999 ? 2 : 0
                borderAnimated: root.windowVisible && Appearance.animationsEnabled
            }

            ColumnLayout {
                x: 22; width: parent.width - 44
                y: sizer.bodyY + root.fh + 18 + (1 - reveal.content) * 10
                transform: Scale { origin.x: (root.panelWidth - 44) / 2; xScale: root.onLeft ? -1 : 1 }
                opacity: reveal.content
                height: root.panelHeight - 36
                spacing: 14

                // ── En-tête ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text { text: ShellState.dnd ? "󰂛" : "󰂚"; font.family: Appearance.font.family; font.pixelSize: 24; color: Appearance.colors.accent }
                    Text { text: "Notifications"; font.family: Appearance.font.family; font.pixelSize: 19; font.weight: Font.Bold; color: Appearance.colors.fg }
                    Rectangle {
                        visible: NotificationService.count > 0
                        implicitWidth: nC.implicitWidth + 18; implicitHeight: 24; radius: root.rad(24)
                        color: ColorUtils.applyAlpha(root.glow, 0.2); border.width: 1; border.color: ColorUtils.applyAlpha(root.glow, 0.6)
                        Text { id: nC; anchors.centerIn: parent; text: NotificationService.count
                               font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg }
                    }
                    Item { Layout.fillWidth: true }
                    IconBtn { glyph: "󰂛"; on: ShellState.dnd; onTap: ShellState.dnd = !ShellState.dnd }   // ne pas déranger
                    IconBtn { glyph: "󰆴"; enabled: NotificationService.count > 0; onTap: NotificationService.dismissAll() }   // tout effacer
                    IconBtn { glyph: "󰅖"; onTap: Popups.notifCenterOpen = false }
                }
                Text {
                    visible: ShellState.dnd
                    text: "Ne pas déranger : les notifications arrivent ici sans s'afficher (sauf les urgentes)"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim
                }

                // ── La liste, par application ─────────────────────────────────
                Flickable {
                    id: flick
                    visible: NotificationService.count > 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentHeight: groupsCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: groupsCol
                        width: flick.width
                        spacing: 18
                        Repeater {
                            model: root.groups
                            delegate: Column {
                                id: g
                                required property var modelData
                                required property int index
                                width: groupsCol.width
                                spacing: 8
                                // arrivée en cascade, une fois le panneau déroulé
                                opacity: Math.max(0, Math.min(1, reveal.content * 2.2 - g.index * 0.2))
                                transform: Translate { y: (1 - g.opacity) * 14 }
                                Row {
                                    x: 4; spacing: 8
                                    Text { text: g.modelData.app.toUpperCase(); font.family: Appearance.font.family; font.pixelSize: 11
                                           font.weight: Font.Bold; font.letterSpacing: 2; color: root.glow }
                                    Text { text: g.modelData.items.length > 1 ? g.modelData.items.length : ""
                                           font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                                }
                                Repeater {
                                    model: ScriptModel { values: g.modelData.items }
                                    delegate: NotifCard {
                                        required property var modelData
                                        width: g.width; height: implicitHeight
                                        notif: modelData
                                        compact: true
                                        animatedBorder: false
                                    }
                                }
                            }
                        }
                    }
                }
                // rien à afficher
                Item {
                    visible: NotificationService.count === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ShellState.dnd ? "󰂛" : "󰂜"
                               font.family: Appearance.font.family; font.pixelSize: 90; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Aucune notification"
                               font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.dim }
                    }
                }
            }
        }
        }

        // Bordure de la forme animée (trait du bord + raccords + corps, un seul tracé),
        // en dégradé animé comme celle du panneau fini
        MorphShape {
            id: morphLine
            color: "transparent"
            borderColor: Appearance.outline
            borderWidth: 2
            borderAnimated: Appearance.animationsEnabled && visible
        }
    }

    // ── Bouton rond ───────────────────────────────────────────────────────────
    component IconBtn: Rectangle {
        id: btn
        property string glyph
        property int size: 40
        property bool on: false
        property bool primary: false
        signal tap()
        implicitWidth: size; implicitHeight: size; radius: size / 2
        opacity: enabled ? 1 : 0.35
        color: primary ? Appearance.colors.accent
             : hov.hovered ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.14)
             : on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.25) : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
        Text {
            anchors.centerIn: parent; text: btn.glyph
            font.family: Appearance.font.family; font.pixelSize: btn.size * 0.5
            color: btn.primary ? Appearance.textOn(Appearance.colors.accent)
                 : btn.on ? Appearance.colors.accent : Appearance.colors.fg
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: btn.tap() }
    }

}

