import QtQuick
import QtQuick.Shapes
import qs.core
import qs.core.functions

// AppsLauncher — toutes les applis enregistrées (core/AppDeck.qml, Réglages › Apps), affichées par-dessus
// l'onglet Apps quand on touche le bouton Apps. Cinq styles au choix ([apps] launcher_style) :
//   spotlight  recherche + grille, les fenêtres en cours reculent et se floutent
//   dock       grand dock qui monte du bas, les icônes grossissent sous le doigt (loupe)
//   hive       alvéoles hexagonales qui se forment par vagues depuis le centre
//   coverflow  rangée en perspective, l'appli du centre en face (toucher : centrer, puis lancer)
//   iris       cercle qui s'ouvre depuis le bouton, applis en vague depuis le bouton
// Toucher une appli : sa fenêtre si elle est déjà ouverte (pickApp du parent), sinon la lance ; fond = fermer.
Item {
    id: lc
    property bool open: false
    property point origin: Qt.point(width - 80, height - 80)     // centre du bouton Apps
    property string style: String(Config.get("apps.launcher_style", "spotlight"))
    signal pick(var app)                                        // toucher
    signal pickNew(var app)                                     // appui long : nouvelle instance
    function close() { open = false }

    // progression globale 0 → 1 (les tuiles ont en plus leur propre délai)
    property real p: open ? 1 : 0
    Behavior on p { NumberAnimation { duration: Appearance.dur(lc.open ? 520 : 300); easing.type: Easing.OutCubic } }
    visible: p > 0.001
    clip: true

    readonly property var apps: AppDeck.sections.reduce((l, s) => l.concat((s.items || []).map(a =>
                                    Object.assign({}, a, { secColor: AppDeck.color(s.accent) }))), [])
    property string query: ""
    onOpenChanged: if (!open) query = ""
    readonly property var shownApps: query === "" ? apps : apps.filter(a => (a.label || "").toLowerCase().indexOf(query.toLowerCase()) >= 0)
    function dist(x, y) { return Math.hypot(x - origin.x, y - origin.y) }

    // ── fond : assombrit et ferme au toucher (Iris : le cercle fait office de fond) ──
    Rectangle {
        anchors.fill: parent
        visible: lc.style !== "iris"
        color: ColorUtils.applyAlpha(Appearance.colors.bg, (lc.style === "spotlight" ? 0.55 : 0.82) * lc.p)
        MouseArea { anchors.fill: parent; onClicked: lc.close() }
    }
    Rectangle {                                     // Iris
        visible: lc.style === "iris"
        readonly property real reach: Math.max(lc.dist(0, 0), lc.dist(lc.width, 0), lc.dist(0, lc.height), lc.dist(lc.width, lc.height))
        width: 2 * reach * lc.p; height: width; radius: width / 2
        x: lc.origin.x - width / 2; y: lc.origin.y - height / 2
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95)
        border.width: lc.p < 0.98 ? 2 : 0; border.color: Appearance.colors.accent
        MouseArea { anchors.fill: parent; onClicked: lc.close() }
    }

    // ── tuile commune (icône + nom) ──
    component Tile: Item {
        id: tile
        property var app
        property real size: 104
        property int delay: 0
        property bool labels: true
        // apparition propre à la tuile, décalée de « delay »
        property real k: lc.open ? 1 : 0
        Behavior on k { SequentialAnimation {
            PauseAnimation { duration: lc.open ? Appearance.dur(tile.delay) : 0 }
            NumberAnimation { duration: Appearance.dur(lc.open ? 360 : 180); easing.type: lc.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.2 }
        } }
        width: size; height: size + (labels ? 26 : 0)
        opacity: Math.min(1, k * 1.4)
        scale: (0.4 + 0.6 * k) * (ma.pressed ? 0.92 : 1)
        Rectangle {
            id: plate
            width: tile.size; height: tile.size; radius: tile.size * 0.26
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.9)
            border.width: 1; border.color: ColorUtils.applyAlpha(tile.app?.secColor ?? Appearance.colors.accent, 0.45)
            Image { anchors.centerIn: parent; width: tile.size * 0.58; height: width; sourceSize: Qt.size(width * 2, width * 2)
                    source: AppDeck.iconSource(tile.app?.appicon); smooth: true; mipmap: true }
        }
        Text { visible: tile.labels; anchors { top: plate.bottom; topMargin: 6; horizontalCenter: plate.horizontalCenter }
               width: tile.size + 20; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
               text: tile.app?.label ?? ""; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.fg }
        MouseArea { id: ma; anchors.fill: parent; onClicked: lc.pick(tile.app); onPressAndHold: lc.pickNew(tile.app) }
    }

    // ═════ Spotlight & Iris : grille centrée ═════
    Item {
        id: gridBox
        visible: lc.style === "spotlight" || lc.style === "iris"
        anchors.fill: parent
        readonly property bool spot: lc.style === "spotlight"
        // recherche (Spotlight)
        Rectangle {
            id: search
            visible: gridBox.spot
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 }
            width: Math.min(900, parent.width * 0.5); height: 56; radius: 28
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95)
            border.width: 1; border.color: Appearance.colors.accent
            opacity: lc.p; scale: 0.94 + 0.06 * lc.p
            Text { id: glass; anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                   text: "󰍉"; font.family: Appearance.font.family; font.pixelSize: 22; color: Appearance.colors.accent }
            TextInput {
                id: field
                anchors { left: glass.right; leftMargin: 14; right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                font.family: Appearance.font.family; font.pixelSize: 20; color: Appearance.colors.fg
                text: lc.query; onTextChanged: lc.query = text
                Keys.onEscapePressed: lc.close()
                Keys.onReturnPressed: if (lc.shownApps.length) lc.pick(lc.shownApps[0])
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !field.text && !field.activeFocus
                       text: "Rechercher une appli…"; font: field.font; color: Appearance.colors.dim }
            }
        }
        Connections { target: lc; function onOpenChanged() { if (lc.open && lc.style === "spotlight") Qt.callLater(() => field.forceActiveFocus()) } }

        Flow {
            id: flow
            readonly property int cols: Math.max(1, Math.floor((parent.width - 60) / (104 + 34)))
            width: Math.min(lc.shownApps.length, cols) * (104 + 34) - 34
            anchors { horizontalCenter: parent.horizontalCenter; top: gridBox.spot ? search.bottom : parent.top; topMargin: gridBox.spot ? 26 : 40 }
            spacing: 34
            scale: gridBox.spot ? 1.06 - 0.06 * lc.p : 1
            Repeater {
                model: gridBox.visible ? lc.shownApps : []
                delegate: Tile {
                    required property var modelData
                    required property int index
                    app: modelData
                    // Spotlight : cascade ; Iris : vague depuis le bouton
                    delay: gridBox.spot ? index * 14 : 120 + lc.dist(flow.x + x + 52, flow.y + y + 52) * 0.32
                }
            }
        }
        Text { anchors.centerIn: parent; visible: gridBox.spot && lc.shownApps.length === 0 && lc.query !== ""
               text: "Aucune appli « " + lc.query + " »"; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.dim }
    }

    // ═════ Dock loupe ═════
    Rectangle {
        id: dock
        visible: lc.style === "dock"
        readonly property int n: lc.apps.length
        readonly property real gx: Math.min(92, (lc.width - 2 * 190) / Math.max(1, n))   // libre de part et d'autre du bouton Apps
        readonly property real ts: gx - 12
        property real mx: -1e4                                  // abscisse du doigt / pointeur
        width: n * gx + 36; height: ts + 44; radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: lc.height - height - 26 + (1 - lc.p) * (height + 60)
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.4)
        Repeater {
            model: dock.visible ? lc.apps : []
            delegate: Item {
                id: dt
                required property var modelData
                required property int index
                readonly property real cx: 18 + index * dock.gx + dock.gx / 2
                readonly property real m: 1 + 0.8 * Math.max(0, 1 - Math.abs(dock.mx - cx) / (dock.gx * 2.4))
                x: cx - dock.ts / 2; y: dock.height - 22 - dock.ts
                width: dock.ts; height: dock.ts
                transformOrigin: Item.Bottom
                scale: m
                Behavior on scale { NumberAnimation { duration: 90 } }
                Rectangle { anchors.fill: parent; radius: width * 0.26; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
                            border.width: 1; border.color: ColorUtils.applyAlpha(dt.modelData.secColor, 0.4) }
                Image { anchors.centerIn: parent; width: parent.width * 0.7; height: width; sourceSize: Qt.size(160, 160)
                        source: AppDeck.iconSource(dt.modelData.appicon); smooth: true; mipmap: true }
                Rectangle {                                     // nom au-dessus de l'icône la plus grosse
                    visible: dt.m > 1.6
                    anchors { bottom: parent.top; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
                    width: nm.implicitWidth + 20; height: 28; radius: 14
                    scale: 1 / dt.m
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95); border.width: 1; border.color: Appearance.colors.accent
                    Text { id: nm; anchors.centerIn: parent; text: dt.modelData.label || ""; font.family: Appearance.font.family
                           font.pixelSize: 14; color: Appearance.colors.fg }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: (m) => dock.mx = m.x
            onPressed: (m) => dock.mx = m.x
            onExited: dock.mx = -1e4
            function at(x) { const i = Math.floor((x - 18) / dock.gx); return i >= 0 && i < dock.n ? lc.apps[i] : null }
            onClicked: (m) => { const a = at(m.x); if (a) lc.pick(a) }
            onPressAndHold: (m) => { const a = at(m.x); if (a) lc.pickNew(a) }
        }
    }

    // ═════ Ruche ═════
    Item {
        id: hive
        visible: lc.style === "hive"
        anchors.fill: parent
        readonly property real hw: 132                          // largeur d'une alvéole
        readonly property real hh: 150
        readonly property int rows: Math.max(1, Math.floor((height - 40 - hh) / (hh * 0.76)) + 1)
        readonly property int cols: Math.ceil(lc.apps.length / rows)
        readonly property real x0: (width - (cols * hw + hw / 2)) / 2
        readonly property real y0: (height - (hh + (rows - 1) * hh * 0.76)) / 2
        Repeater {
            model: hive.visible ? lc.apps : []
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property int r: Math.floor(index / hive.cols)
                readonly property int c: index % hive.cols
                property real k: lc.open ? 1 : 0
                Behavior on k { SequentialAnimation {
                    PauseAnimation { duration: lc.open ? Appearance.dur(70 + 85 * Math.round(Math.hypot(cell.c - (hive.cols - 1) / 2, (cell.r - (hive.rows - 1) / 2) * 1.3))) : 0 }
                    NumberAnimation { duration: Appearance.dur(lc.open ? 420 : 160); easing.type: lc.open ? Easing.OutBack : Easing.InCubic }
                } }
                x: hive.x0 + c * hive.hw + (r % 2) * hive.hw / 2; y: hive.y0 + r * hive.hh * 0.76
                width: hive.hw - 6; height: hive.hh - 6
                opacity: Math.min(1, k * 1.5); scale: k * (hm.pressed ? 0.92 : 1); rotation: (1 - k) * 30
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 1.5; strokeColor: ColorUtils.applyAlpha(cell.modelData.secColor, 0.6)
                        fillColor: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
                        PathPolyline { path: [Qt.point(cell.width / 2, 0), Qt.point(cell.width, cell.height * 0.25), Qt.point(cell.width, cell.height * 0.75),
                                              Qt.point(cell.width / 2, cell.height), Qt.point(0, cell.height * 0.75), Qt.point(0, cell.height * 0.25),
                                              Qt.point(cell.width / 2, 0)] }
                    }
                }
                Image { anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -9 }
                        width: 56; height: 56; sourceSize: Qt.size(112, 112); source: AppDeck.iconSource(cell.modelData.appicon); mipmap: true }
                Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: cell.height * 0.2 }
                       width: parent.width * 0.8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                       text: cell.modelData.label || ""; font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                MouseArea { id: hm; anchors.fill: parent; anchors.margins: 12
                            onClicked: lc.pick(cell.modelData); onPressAndHold: lc.pickNew(cell.modelData) }
            }
        }
    }

    // ═════ Coverflow ═════
    ListView {
        id: cover
        visible: lc.style === "coverflow"
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 360
        orientation: ListView.Horizontal
        model: visible ? lc.apps : []
        spacing: -40
        preferredHighlightBegin: width / 2 - 120; preferredHighlightEnd: width / 2 + 120
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Appearance.dur(320)
        snapMode: ListView.SnapToItem
        boundsBehavior: Flickable.StopAtBounds
        opacity: lc.p
        Connections { target: lc; function onOpenChanged() { if (lc.open && cover.visible) Qt.callLater(() => { cover.currentIndex = Math.floor(cover.count / 2); cover.positionViewAtIndex(cover.currentIndex, ListView.Center) }) } }
        property real acc: 0
        WheelHandler { onWheel: (e) => { cover.acc += e.angleDelta.y || e.angleDelta.x
                                         while (Math.abs(cover.acc) >= 120) { const s = cover.acc < 0 ? 1 : -1; cover.acc += s * 120
                                             cover.currentIndex = Math.max(0, Math.min(cover.count - 1, cover.currentIndex + s)) } } }
        delegate: Item {
            id: cf
            required property var modelData
            required property int index
            readonly property real dist: (x + width / 2 - cover.contentX - cover.width / 2) / (width + cover.spacing)
            readonly property real ad: Math.min(Math.abs(dist), 5)
            readonly property bool cur: ListView.isCurrentItem
            width: 240; height: cover.height
            z: 10 - ad
            scale: (ad < 1 ? 1.15 - 0.3 * ad : 0.85 - (ad - 1) * 0.06) * (1 - (1 - lc.p) * 0.3)
            opacity: Math.max(0, 1 - ad * 0.18)
            transform: Rotation { origin.x: cf.width / 2; origin.y: cf.height / 2; axis { x: 0; y: 1; z: 0 }
                                  angle: Math.max(-58, Math.min(58, -cf.dist * 40)) * lc.p + (1 - lc.p) * 90 }
            Rectangle {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter; y: 40
                width: 210; height: 210; radius: 46
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95)
                border.width: cf.cur ? 2 : 1; border.color: ColorUtils.applyAlpha(cf.modelData.secColor, cf.cur ? 0.9 : 0.35)
                Image { anchors.centerIn: parent; width: 120; height: 120; sourceSize: Qt.size(240, 240)
                        source: AppDeck.iconSource(cf.modelData.appicon); mipmap: true }
            }
            Text { anchors { top: face.bottom; topMargin: 18; horizontalCenter: face.horizontalCenter }
                   opacity: cf.cur ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
                   text: cf.modelData.label || ""; font.family: Appearance.font.family; font.pixelSize: 22; font.weight: Font.DemiBold
                   color: Appearance.colors.fg }
            MouseArea { anchors.fill: face
                        onClicked: cf.cur ? lc.pick(cf.modelData) : cover.currentIndex = cf.index
                        onPressAndHold: lc.pickNew(cf.modelData)
                        onWheel: (w) => w.accepted = false }
        }
    }
}
