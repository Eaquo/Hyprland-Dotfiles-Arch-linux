import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "." as T
import Quickshell
import qs.core
import qs.core.functions

// Apps — lanceur d'applications (les .desktop installés), comme rofi -show drun. Six dispositions
// ([menu] apps_layout, aussi dans la liste du bouton de thème de l'en-tête), toutes au clavier et à la souris :
//   grid       grille, icône au-dessus du nom (défaut)
//   spotlight  deux volets : liste à gauche, fiche de l'appli choisie à droite (halo, description, catégories)
//   iris       « Orbite » : l'appli choisie au centre, les autres gravitent sur deux anneaux et glissent
//   hive       alvéoles hexagonales centrées, l'alvéole choisie grossit et s'illumine
//   coverflow  rangée en perspective avec reflet au sol et halo derrière l'appli du centre
//   dock       fiche de l'appli choisie en haut, dock à effet loupe en bas
T.Grid {
    id: a
    readonly property string layout: String(Config.get("menu.apps_layout", "grid"))
    showGrid: layout === "grid"
    prefW: 1720
    // colonnes : servent aussi aux flèches haut / bas du menu (pas d'une rangée)
    cols: layout === "grid" ? (menu.req.columns > 0 ? menu.req.columns : 5) : layout === "hive" ? hiveCols : 1
    rows: layout === "spotlight" ? 8 : 5
    ratio: 0.3
    property bool horizontal: layout === "coverflow" || layout === "dock" || layout === "iris"
    readonly property real altH: ({ spotlight: 8 * 60, iris: 600, hive: 560, coverflow: 470, dock: 470 })[layout] || 0
    contentH: layout === "grid" ? Math.min(Math.ceil(menu.items.length / cols), rows) * Math.round(Math.floor((menu.fullW - 52) / cols) * ratio) : altH

    // liaison : se remplit dès que Quickshell a fini de lire les .desktop
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ t: e.name, sub: e.genericName || e.comment || "", icon: e.icon, entry: e }))
        .sort((x, y) => x.t.localeCompare(y.t))
    onAppsChanged: menu.extra = apps
    Component.onCompleted: menu.extra = apps

    readonly property var curItem: menu.items[menu.cur] || null
    function hover(i) { if (menu.hoverReady) menu.cur = i }
    function cats(it) {
        const c = it && it.entry && it.entry.categories ? it.entry.categories : []
        return c.filter(x => !/^(X-|GTK|Qt|KDE|GNOME)/.test(x)).slice(0, 4)
    }

    tile: Component {
        Item {
            property var it: ({ t: "" })
            property bool on: false
            Rectangle {
                anchors.fill: parent; radius: a.menu.rad(height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.065 : 0.05) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.03 : 0.012) }
                }
                Rectangle { x: parent.radius; width: parent.width - parent.radius * 2; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46; height: 46; sourceSize: Qt.size(96, 96)
                    source: a.menu.iconSrc(it.icon); asynchronous: true
                    scale: on ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(180); easing.type: Easing.OutBack } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: a.cw - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: a.menu.mark(it.t, "", on); textFormat: Text.StyledText
                    font.family: Appearance.font.family; font.pixelSize: 15
                    color: on ? a.menu.glow : Appearance.colors.fg
                }
            }
        }
    }

    // ── Fiche de l'appli choisie (Spotlight à droite, Dock en haut) : icône sur halo, nom, description ──
    component Hero: Item {
        id: hero
        property bool wide: true                     // true : icône au-dessus (Spotlight), false : à gauche (Dock)
        readonly property var it: a.curItem
        // halo : l'icône floutée en grand derrière
        Image { id: heroSrc; source: hero.it ? a.menu.iconSrc(hero.it.icon) : ""; sourceSize: Qt.size(256, 256); visible: false; asynchronous: true }
        MultiEffect {
            source: heroSrc
            width: hero.wide ? 340 : 260; height: width
            x: hero.wide ? (hero.width - width) / 2 : -40; y: hero.wide ? 10 : (hero.height - height) / 2
            blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2
            opacity: 0.55; saturation: 0.4
        }
        Image {
            id: big
            source: heroSrc.source; sourceSize: Qt.size(256, 256); asynchronous: true
            width: hero.wide ? 150 : 112; height: width
            x: hero.wide ? (hero.width - width) / 2 : 34; y: hero.wide ? 70 : (hero.height - height) / 2
            // petit rebond à chaque changement d'appli
            onSourceChanged: bump.restart()
            SequentialAnimation { id: bump
                NumberAnimation { target: big; property: "scale"; from: 0.82; to: 1.04; duration: Appearance.dur(200); easing.type: Easing.OutCubic }
                NumberAnimation { target: big; property: "scale"; to: 1; duration: Appearance.dur(160) } }
        }
        Column {
            x: hero.wide ? 30 : big.x + big.width + 34
            y: hero.wide ? big.y + big.height + 30 : (hero.height - height) / 2
            width: hero.wide ? hero.width - 60 : hero.width - x - 30
            spacing: 10
            Text { width: parent.width; horizontalAlignment: hero.wide ? Text.AlignHCenter : Text.AlignLeft; elide: Text.ElideRight
                   text: hero.it ? hero.it.t : ""; font.family: Appearance.font.family; font.pixelSize: hero.wide ? 28 : 30
                   font.weight: Font.Bold; color: Appearance.colors.fg }
            Text { width: parent.width; horizontalAlignment: hero.wide ? Text.AlignHCenter : Text.AlignLeft
                   wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                   text: hero.it ? (hero.it.entry && hero.it.entry.comment) || hero.it.sub || "" : ""; visible: text !== ""
                   font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.dim }
            Flow {
                width: parent.width; spacing: 8
                layoutDirection: Qt.LeftToRight
                Repeater {
                    model: a.cats(hero.it)
                    delegate: Rectangle {
                        required property var modelData
                        width: ct.implicitWidth + 22; height: 28; radius: 14
                        color: ColorUtils.applyAlpha(a.menu.glow, 0.14); border.width: 1; border.color: ColorUtils.applyAlpha(a.menu.glow, 0.4)
                        Text { id: ct; anchors.centerIn: parent; text: modelData; font.family: Appearance.font.family; font.pixelSize: 12; color: a.menu.glow }
                    }
                }
            }
            Text { text: "↵  Lancer"; font.family: Appearance.font.family; font.pixelSize: 13; color: ColorUtils.applyAlpha(a.menu.glow, 0.8)
                   horizontalAlignment: hero.wide ? Text.AlignHCenter : Text.AlignLeft; width: parent.width }
        }
    }

    // ═════ Spotlight : liste + fiche ═════
    Item {
        visible: a.layout === "spotlight"
        anchors.fill: parent
        ListView {
            id: spot
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * 0.5
            model: parent.visible ? a.menu.items : []
            currentIndex: a.menu.cur
            highlightMoveDuration: Appearance.dur(160)
            clip: true; boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: index === a.menu.cur
                width: spot.width; height: 60
                Rectangle {
                    anchors { fill: parent; margins: 3 }
                    radius: a.menu.rad(height)
                    color: row.on ? ColorUtils.applyAlpha(a.menu.glow, 0.18) : "transparent"
                    border.width: row.on ? 1 : 0; border.color: ColorUtils.applyAlpha(a.menu.glow, 0.6)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                }
                Image { id: si; x: 16; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; sourceSize: Qt.size(72, 72)
                        source: a.menu.iconSrc(row.modelData.icon); asynchronous: true }
                Column {
                    anchors { left: si.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; elide: Text.ElideRight; text: a.menu.mark(row.modelData.t, "", row.on); textFormat: Text.StyledText
                           font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                           color: row.on ? a.menu.glow : Appearance.colors.fg }
                    Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.sub || ""; visible: text !== ""
                           font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: a.hover(row.index); onClicked: a.menu.choose(row.index) }
            }
        }
        Rectangle { id: sep; x: spot.width + 12; width: 1; height: parent.height; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) }
        Hero { anchors { left: sep.right; right: parent.right; top: parent.top; bottom: parent.bottom } wide: true }
    }

    // ═════ Orbite (iris) : l'appli choisie au centre, deux anneaux autour ═════
    Item {
        id: orbit
        visible: a.layout === "iris"
        anchors.fill: parent
        readonly property real cx: width / 2
        readonly property real cy: height / 2 - 10
        readonly property real rx1: Math.min(330, width * 0.2)
        readonly property real ry1: 150
        readonly property real rx2: Math.min(680, width * 0.42)
        readonly property real ry2: 248
        // anneaux
        Canvas {
            anchors.fill: parent
            readonly property color c: a.menu.glow
            onCChanged: requestPaint(); onWidthChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.reset()
                g.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.14); g.lineWidth = 1.2
                for (const [rx, ry] of [[orbit.rx1, orbit.ry1], [orbit.rx2, orbit.ry2]]) {
                    g.beginPath(); g.ellipse(orbit.cx - rx, orbit.cy - ry, rx * 2, ry * 2); g.stroke()
                }
            }
        }
        // halo derrière l'appli centrale
        Rectangle { width: 240; height: 240; radius: 120; x: orbit.cx - 120; y: orbit.cy - 120
                    color: ColorUtils.applyAlpha(a.menu.glow, 0.10) }
        Repeater {
            model: orbit.visible ? a.menu.items : []
            delegate: Item {
                id: sat
                required property var modelData
                required property int index
                readonly property int d: index - a.menu.cur
                readonly property int ad: Math.abs(d)
                readonly property bool on: d === 0
                // place sur l'anneau : 1er anneau ±1..±3 (6 places), 2e ±4..±9 (12 places), au-delà : caché au loin
                readonly property real ang: ad <= 3 ? ((d > 0 ? d - 1 : 6 + d) / 6) * 2 * Math.PI - Math.PI / 2 + Math.PI / 6
                                          : (((d > 0 ? d - 4 : 18 + d)) / 12) * 2 * Math.PI - Math.PI / 2 + Math.PI / 12
                readonly property real px: on ? orbit.cx : ad <= 3 ? orbit.cx + orbit.rx1 * Math.cos(ang) : orbit.cx + orbit.rx2 * Math.cos(ang) * (ad <= 9 ? 1 : 1.3)
                readonly property real py: on ? orbit.cy : ad <= 3 ? orbit.cy + orbit.ry1 * Math.sin(ang) : orbit.cy + orbit.ry2 * Math.sin(ang) * (ad <= 9 ? 1 : 1.3)
                readonly property real sz: on ? 132 : ad <= 3 ? 78 : 58
                visible: ad <= 11
                x: px - width / 2; y: py - height / 2
                width: sz; height: sz
                opacity: on ? 1 : ad <= 3 ? 0.9 : ad <= 9 ? 0.6 : 0
                z: 20 - ad
                Behavior on x { NumberAnimation { duration: Appearance.dur(380); easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Appearance.dur(380); easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Appearance.dur(300); easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Appearance.dur(300); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                Rectangle {
                    anchors.fill: parent; radius: width * 0.28
                    color: sat.on ? ColorUtils.applyAlpha(a.menu.glow, 0.16) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
                    border.width: sat.on ? 2 : 1; border.color: sat.on ? a.menu.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                }
                Image { anchors.centerIn: parent; width: parent.width * 0.62; height: width; sourceSize: Qt.size(192, 192)
                        source: a.menu.iconSrc(sat.modelData.icon); asynchronous: true }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: sat.on ? a.menu.choose(sat.index) : a.menu.cur = sat.index }
            }
        }
        // nom de l'appli centrale
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: orbit.cy + 82
               text: a.curItem ? a.curItem.t : ""; font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold
               color: a.menu.glow }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: orbit.cy + 110; width: 460; horizontalAlignment: Text.AlignHCenter
               elide: Text.ElideRight; text: a.curItem ? a.curItem.sub || "" : ""; font.family: Appearance.font.family; font.pixelSize: 13
               color: Appearance.colors.dim }
        WheelHandler { onWheel: (e) => a.menu.cur = Math.max(0, Math.min(a.menu.items.length - 1, a.menu.cur + (e.angleDelta.y < 0 ? 1 : -1))) }
    }

    // ═════ Ruche : grandes alvéoles centrées ═════
    readonly property real hw: 150
    readonly property real hh: 168
    readonly property int hiveCols: Math.max(1, Math.floor((width - hw / 2 - 20) / hw))
    Flickable {
        id: hive
        visible: a.layout === "hive"
        anchors.fill: parent
        clip: true; boundsBehavior: Flickable.StopAtBounds
        contentHeight: Math.ceil(a.menu.items.length / a.hiveCols) * a.hh * 0.78 + a.hh * 0.22 + 30
        readonly property real x0: (width - (a.hiveCols * a.hw + a.hw / 2)) / 2
        readonly property real curY: Math.floor(a.menu.cur / a.hiveCols) * a.hh * 0.78
        onCurYChanged: if (curY < contentY) contentY = curY; else if (curY + a.hh + 20 > contentY + height) contentY = curY + a.hh + 20 - height
        Behavior on contentY { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } }
        Repeater {
            model: hive.visible ? a.menu.items : []
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property int r: Math.floor(index / a.hiveCols)
                readonly property int c: index % a.hiveCols
                readonly property bool on: index === a.menu.cur
                x: hive.x0 + c * a.hw + (r % 2) * a.hw / 2; y: r * a.hh * 0.78 + 12
                width: a.hw - 8; height: a.hh - 8
                z: on ? 10 : 1
                property real k: 0
                scale: k * (on ? 1.16 : 1)
                opacity: k
                Behavior on scale { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutBack } }
                Component.onCompleted: cellIn.start()
                SequentialAnimation { id: cellIn
                    PauseAnimation { duration: Math.min(60 * (cell.r + Math.abs(cell.c - a.hiveCols / 2) / 2), 800) }
                    NumberAnimation { target: cell; property: "k"; to: 1; duration: Appearance.dur(380); easing.type: Easing.OutBack } }
                // lueur de l'alvéole choisie
                MultiEffect {
                    source: hexShape; anchors.fill: hexShape; visible: cell.on
                    blurEnabled: true; blur: 1; blurMax: 32; colorization: 1; colorizationColor: a.menu.glow; opacity: 0.6
                }
                Shape {
                    id: hexShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: cell.on ? 2.5 : 1.2
                        strokeColor: cell.on ? a.menu.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.16)
                        fillColor: cell.on ? Qt.darker(ColorUtils.applyAlpha(a.menu.glow, 1), 3.2) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.045)
                        PathPolyline { path: [Qt.point(cell.width / 2, 0), Qt.point(cell.width, cell.height * 0.25), Qt.point(cell.width, cell.height * 0.75),
                                              Qt.point(cell.width / 2, cell.height), Qt.point(0, cell.height * 0.75), Qt.point(0, cell.height * 0.25),
                                              Qt.point(cell.width / 2, 0)] }
                    }
                }
                Image { anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -10 }
                        width: 56; height: 56; sourceSize: Qt.size(112, 112); source: a.menu.iconSrc(cell.modelData.icon); asynchronous: true }
                Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: cell.height * 0.21 }
                       width: parent.width * 0.74; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                       text: cell.modelData.t; font.family: Appearance.font.family; font.pixelSize: 12
                       color: cell.on ? a.menu.glow : Appearance.colors.dim }
                MouseArea { anchors.fill: parent; anchors.margins: 12; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: a.hover(cell.index); onClicked: a.menu.choose(cell.index) }
            }
        }
    }

    // ═════ Coverflow & Dock : rangée horizontale centrée sur l'appli choisie ═════
    Item {
        visible: a.layout === "coverflow" || a.layout === "dock"
        anchors.fill: parent
        readonly property bool cover: a.layout === "coverflow"
        // Dock : fiche de l'appli en haut
        Hero { visible: !parent.cover; anchors { left: parent.left; right: parent.right; top: parent.top } height: 250; wide: false }
        // Coverflow : halo derrière l'appli du centre
        Rectangle { visible: parent.cover; width: 420; height: 420; radius: 210; anchors.horizontalCenter: parent.horizontalCenter; y: -60
                    color: ColorUtils.applyAlpha(a.menu.glow, 0.09) }
        // Dock : étagère vitrée
        Rectangle { visible: !parent.cover; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 40; rightMargin: 40; bottomMargin: 18 }
                    height: 86; radius: 26; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) }
        ListView {
            id: row
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.cover ? parent.height : 220
            orientation: ListView.Horizontal
            model: parent.visible ? a.menu.items : []
            currentIndex: a.menu.cur
            readonly property bool cover: parent.cover
            readonly property real item: cover ? 230 : 84
            spacing: cover ? -50 : 6
            preferredHighlightBegin: width / 2 - item / 2; preferredHighlightEnd: width / 2 + item / 2
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: Appearance.dur(260)
            boundsBehavior: Flickable.StopAtBounds
            clip: !cover
            delegate: Item {
                id: hc
                required property var modelData
                required property int index
                readonly property bool on: index === a.menu.cur
                readonly property real dist: (x + width / 2 - row.contentX - row.width / 2) / (width + row.spacing)
                readonly property real ad: Math.min(Math.abs(dist), 6)
                width: row.item; height: row.height
                z: 10 - ad
                scale: row.cover ? (ad < 1 ? 1.12 - 0.27 * ad : 0.85 - (ad - 1) * 0.05) : 1 + 0.75 * Math.max(0, 1 - ad / 2.4)
                opacity: row.cover ? Math.max(0, 1 - ad * 0.16) : 1
                transformOrigin: row.cover ? Item.Center : Item.Bottom
                Behavior on scale { enabled: !row.cover; NumberAnimation { duration: 120 } }
                transform: Rotation { origin.x: hc.width / 2; origin.y: hc.height / 2; axis { x: 0; y: 1; z: 0 }
                                      angle: row.cover ? Math.max(-58, Math.min(58, -hc.dist * 40)) : 0 }
                Rectangle {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: row.cover ? 40 : parent.height - height - 28
                    width: row.cover ? 200 : 64; height: width; radius: width * 0.24
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, hc.on ? 0.1 : 0.05)
                    border.width: hc.on ? 2 : 1
                    border.color: hc.on ? a.menu.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.14)
                    Image { id: fi; anchors.centerIn: parent; width: parent.width * 0.62; height: width; sourceSize: Qt.size(240, 240)
                            source: a.menu.iconSrc(hc.modelData.icon); asynchronous: true }
                }
                // Coverflow : reflet au sol (carte retournée, qui s'efface vers le bas)
                Item {
                    visible: row.cover
                    anchors.horizontalCenter: face.horizontalCenter
                    y: face.y + face.height + 6; width: face.width; height: face.height * 0.5; clip: true
                    Rectangle {
                        width: face.width; height: face.height; radius: face.radius
                        color: face.color; border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                        transform: Scale { origin.y: face.height / 2; yScale: -1 }
                        Image { anchors.centerIn: parent; width: fi.width; height: fi.height; sourceSize: Qt.size(240, 240); source: fi.source; asynchronous: true }
                    }
                    Rectangle { anchors.fill: parent
                                gradient: Gradient { GradientStop { position: 0; color: ColorUtils.applyAlpha(a.menu.cardBg, 0.55) }
                                                     GradientStop { position: 1; color: a.menu.cardBg } } }
                }
                Text {
                    visible: hc.on && row.cover
                    anchors { horizontalCenter: face.horizontalCenter; top: face.bottom; topMargin: 118 }
                    text: hc.modelData.t; font.family: Appearance.font.family; font.weight: Font.DemiBold
                    font.pixelSize: 22; color: a.menu.glow
                }
                MouseArea { anchors.fill: face; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: if (!row.cover) a.hover(hc.index)
                            onClicked: hc.on || !row.cover ? a.menu.choose(hc.index) : a.menu.cur = hc.index }
            }
        }
    }
}
