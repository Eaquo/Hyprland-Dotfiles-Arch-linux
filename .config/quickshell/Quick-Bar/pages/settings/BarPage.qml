import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// BarPage — Réglages › Barre › Modules : disposition ([bar.layout]) par glisser-déposer,
// géométrie et options ([bar]). La barre suit en direct.
ColumnLayout {
    id: page
    spacing: 18

    readonly property var sides: [["left", "Gauche"], ["center", "Centre"], ["right", "Droite"], ["hidden", "Désactivés"]]
    readonly property var lay: {
        const l = { left: BarModules.layout("left"), center: BarModules.layout("center"), right: BarModules.layout("right") }
        const used = l.left.concat(l.center, l.right)
        l.hidden = BarModules.list.map(m => m.key).filter(k => used.indexOf(k) < 0)
        return l
    }

    function save(l) {
        for (const s of ["left", "center", "right"]) Config.set("bar.layout." + s, l[s])
    }
    function moveTo(key, to, idx) {
        const l = { left: lay.left.slice(), center: lay.center.slice(), right: lay.right.slice(), hidden: lay.hidden.slice() }
        for (const s in l) {
            const i = l[s].indexOf(key)
            if (i < 0) continue
            l[s].splice(i, 1)
            if (s === to && i < idx) idx--
        }
        l[to].splice(Math.max(0, Math.min(idx, l[to].length)), 0, key)
        save(l)
    }

    // ── Options par module (clic droit ou ⚙) ──
    property string optKey: ""
    // ouvert depuis le clic droit d'une stat dans la barre → options des stats
    function takeHint() { if (Popups.settingsHint !== "") { optKey = Popups.settingsHint; Popups.settingsHint = "" } }
    Component.onCompleted: takeHint()
    Connections { target: Popups; function onSettingsHintChanged() { page.takeHint() } }
    function hasOptions(k) { return k === "stats" || k === "clock" }
    readonly property var statsAll: [
        { key: "cpu", icon: "󰍛", label: "Processeur (charge)" }, { key: "ram", icon: "󰾆", label: "Mémoire" },
        { key: "tcpu", icon: "󰔏", label: "Température CPU" }, { key: "tgpu", icon: "󰢮", label: "Température GPU" },
        { key: "tnvme", icon: "󰆼", label: "Température NVMe" }, { key: "disk", icon: "󰋊", label: "Disque" }
    ]
    readonly property var statsItems: {
        const v = Config.get("bar.stats", statsAll.map(t => t.key))
        const keys = Array.isArray(v) ? v : []
        return keys.map(k => statsAll.find(t => t.key === k)).filter(t => t).map(t => Object.assign({}, t, { on: true }))
            .concat(statsAll.filter(t => keys.indexOf(t.key) < 0).map(t => Object.assign({}, t, { on: false })))
    }

    // Désactive un module, ou le remet à sa place par défaut (sinon à droite)
    function toggleModule(key) {
        if (lay.hidden.indexOf(key) < 0) { moveTo(key, "hidden", lay.hidden.length); return }
        let side = "right", idx = lay.right.length
        for (const s of ["left", "center", "right"]) {
            const d = BarModules.defaults[s].indexOf(key)
            if (d >= 0) { side = s; idx = Math.min(d, lay[s].length) }
        }
        moveTo(key, side, idx)
    }

    // ── Glisser-déposer ──
    readonly property int chipH: 42
    readonly property int chipGap: 6
    property string dragKey: ""
    property point dragPos
    property string dropSide: ""
    property int dropIndex: -1
    property var cols: ({})
    function dragMove(p) {
        dragPos = p
        dropSide = ""
        for (const s in cols) {
            const c = cols[s], q = page.mapToItem(c, p.x, p.y)
            if (q.x < 0 || q.x > c.width || q.y < -20 || q.y > c.height + 20) continue
            dropSide = s
            dropIndex = Math.max(0, Math.min(lay[s].length, Math.floor((q.y + chipH / 2) / (chipH + chipGap))))
        }
    }
    function dragEnd() {
        if (dragKey !== "" && dropSide !== "") moveTo(dragKey, dropSide, dropIndex)
        dragKey = ""; dropSide = ""
    }

    PageHeader { title: "Modules de la barre"; sub: "[bar.layout] dans config.toml — glisse un module pour le déplacer" }

    // Aperçu : les trois pilules, comme sur la barre
    SetCard {
        title: "Aperçu"
        Item {
            Layout.fillWidth: true
            implicitHeight: 40
            Repeater {
                model: ["left", "center", "right"]
                delegate: Rectangle {
                    id: pv
                    required property string modelData
                    readonly property var keys: page.lay[modelData]
                    visible: keys.length > 0
                    x: modelData === "left" ? 0 : modelData === "right" ? parent.width - width : (parent.width - width) / 2
                    height: 34; radius: Math.min(Appearance.bar.radius, 17)
                    width: prow.implicitWidth + 20
                    color: Appearance.colors.bg
                    border.width: 1; border.color: Appearance.outline
                    Row {
                        id: prow
                        anchors.centerIn: parent
                        spacing: 10
                        Repeater {
                            model: pv.keys
                            delegate: Text {
                                required property string modelData
                                text: BarModules.info(modelData).ic
                                font.family: Appearance.font.family; font.pixelSize: 15
                                color: page.dragKey === modelData ? Appearance.colors.accent : Appearance.colors.fg
                            }
                        }
                    }
                }
            }
        }
    }

    SetCard {
        title: "Disposition"
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: page.sides
                delegate: ColumnLayout {
                    id: colItem
                    required property var modelData
                    readonly property string side: modelData[0]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    RowLayout {
                        Text { text: colItem.modelData[1]; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
                               font.weight: Font.DemiBold; color: colItem.side === "hidden" ? Appearance.colors.dim : Appearance.colors.fg }
                        Text { text: page.lay[colItem.side].length; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                    }
                    Rectangle {
                        id: zone
                        Layout.fillWidth: true
                        implicitHeight: Math.max(1, page.lay[colItem.side].length + (page.dropSide === colItem.side && page.dragKey !== "" ? 1 : 0)) * (page.chipH + page.chipGap) + 10
                        Behavior on implicitHeight { NumberAnimation { duration: Appearance.dur(160); easing.type: Easing.OutCubic } }
                        radius: 12
                        color: page.dropSide === colItem.side ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.08)
                             : ColorUtils.applyAlpha(Appearance.colors.bg, colItem.side === "hidden" ? 0.25 : 0.55)
                        border.width: 1
                        border.color: page.dropSide === colItem.side ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                        Component.onCompleted: { const c = page.cols; c[colItem.side] = list; page.cols = c }

                        Item {
                            id: list
                            x: 5; y: 5; width: parent.width - 10; height: parent.height - 10
                            Text {
                                anchors.centerIn: parent
                                visible: page.lay[colItem.side].length === 0 && page.dropSide !== colItem.side
                                text: colItem.side === "hidden" ? "glisse un module ici\npour le désactiver" : "vide — pilule masquée"
                                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
                            }
                            Repeater {
                                model: page.lay[colItem.side]
                                delegate: Rectangle {
                                    id: chip
                                    required property string modelData
                                    required property int index
                                    readonly property var m: BarModules.info(modelData)
                                    readonly property bool dragging: page.dragKey === modelData
                                    // laisse un trou à l'endroit où le module va tomber
                                    readonly property int shift: page.dragKey !== "" && page.dropSide === colItem.side && index >= page.dropIndex ? 1 : 0
                                    width: list.width; height: page.chipH; radius: 10
                                    y: (index + shift) * (page.chipH + page.chipGap)
                                    Behavior on y { NumberAnimation { duration: Appearance.dur(160); easing.type: Easing.OutCubic } }
                                    opacity: dragging ? 0.3 : (colItem.side === "hidden" ? 0.65 : 1)
                                    color: chipMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.09) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
                                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 10; rightMargin: page.hasOptions(chip.modelData) ? 72 : 40 }
                                        spacing: 8
                                        Text { text: "󰇛"; font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                                        Text { text: chip.m.ic; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.accent }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text { Layout.fillWidth: true; text: chip.m.name; elide: Text.ElideRight
                                                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.fg }
                                            Text { Layout.fillWidth: true; text: chip.m.desc; elide: Text.ElideRight
                                                   font.family: Appearance.font.family; font.pixelSize: 9; color: Appearance.colors.dim }
                                        }
                                    }
                                    MouseArea {
                                        id: chipMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: page.dragKey !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onPressed: (e) => {
                                            if (e.button === Qt.RightButton) { if (page.hasOptions(chip.modelData)) page.optKey = chip.modelData; return }
                                            page.dragKey = chip.modelData; page.dragMove(mapToItem(page, e.x, e.y))
                                        }
                                        onPositionChanged: (e) => { if (pressed) page.dragMove(mapToItem(page, e.x, e.y)) }
                                        onReleased: (e) => { if (e.button !== Qt.RightButton) page.dragEnd() }
                                        onCanceled: { page.dragKey = ""; page.dropSide = "" }
                                    }
                                    // Options du module (clic droit aussi)
                                    Rectangle {
                                        visible: page.hasOptions(chip.modelData)
                                        anchors { right: hideBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                        width: 28; height: 28; radius: 8
                                        color: optMa.containsMouse || page.optKey === chip.modelData ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.25) : "transparent"
                                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, optMa.containsMouse ? 0.25 : 0.1)
                                        Text { anchors.centerIn: parent; text: "󰒓"; font.family: Appearance.font.family; font.pixelSize: 13
                                               color: page.optKey === chip.modelData ? Appearance.colors.accent : Appearance.colors.dim }
                                        MouseArea { id: optMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: page.optKey = page.optKey === chip.modelData ? "" : chip.modelData }
                                    }
                                    // Désactiver (󰈉) / réactiver (+) sans glisser
                                    Rectangle {
                                        id: hideBtn
                                        readonly property bool off: colItem.side === "hidden"
                                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                        width: 28; height: 28; radius: 8
                                        color: hbMa.containsMouse ? ColorUtils.applyAlpha(off ? Appearance.colors.accent : Appearance.colors.color1, 0.25) : "transparent"
                                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, hbMa.containsMouse ? 0.25 : 0.1)
                                        Text { anchors.centerIn: parent; text: hideBtn.off ? "󰐕" : "󰈉"; font.family: Appearance.font.family; font.pixelSize: 14
                                               color: hideBtn.off ? Appearance.colors.accent : Appearance.colors.dim }
                                        MouseArea {
                                            id: hbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: page.toggleModule(chip.modelData)
                                        }
                                    }
                                }
                            }
                            // repère d'insertion
                            Rectangle {
                                visible: page.dragKey !== "" && page.dropSide === colItem.side
                                y: page.dropIndex * (page.chipH + page.chipGap) - page.chipGap / 2 - 1
                                width: list.width; height: 2; radius: 1
                                color: Appearance.colors.accent
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "󰈉 désactive un module, + le remet à sa place d'origine, 󰒓 (ou clic droit) ouvre ses options ; on peut aussi les glisser. Une pilule vide disparaît de la barre."
                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
            }
            SetButton {
                label: "󰑓  Disposition par défaut"
                onTap: ["left", "center", "right"].forEach(s => Config.set("bar.layout." + s, null))
            }
        }
    }

    SetCard {
        visible: page.optKey !== ""
        title: "Options · " + (page.optKey ? BarModules.info(page.optKey).name : "")
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: page.optKey === "stats" ? "Ordre et affichage de chaque stat du module (les températures restent groupées). Aussi au clic droit sur une stat dans la barre."
                    : "Format de l'heure affichée dans la barre."
                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
            }
            SetButton { label: "󰅖"; onTap: page.optKey = "" }
        }
        SetOrderList {
            visible: page.optKey === "stats"
            Layout.fillWidth: true
            items: page.statsItems
            onEdited: (l) => {
                const keys = l.filter(t => t.on).map(t => t.key)
                Config.set("bar.stats", keys.join() === page.statsAll.map(t => t.key).join() ? null : keys)
            }
        }
        SetRow {
            visible: page.optKey === "clock"
            title: "Format"
            SetSeg {
                options: [["HH:mm:ss", "20:12:45"], ["HH:mm", "20:12"], ["ddd HH:mm", "ven. 20:12"], ["dd/MM HH:mm", "17/10 20:12"]]
                current: String(Config.get("bar.clock_format", "HH:mm:ss"))
                onPicked: (v) => Config.set("bar.clock_format", v === "HH:mm:ss" ? null : v)
            }
        }
    }

    SetCard {
        title: "Apparence"
        SetRow {
            title: "Séparateurs"; desc: "petit trait entre les modules"
            SetSwitch { on: BarModules.separators; onToggled: Config.set("bar.separators", !on) }
        }
        SetRow { title: "Hauteur"; SetSlider { implicitWidth: 300; from: 24; to: 48; suffix: " px"; value: Appearance.bar.height; onMoved: (v) => Config.set("bar.height", v) } }
        SetRow { title: "Arrondi des pilules"; SetSlider { implicitWidth: 300; from: 0; to: 24; suffix: " px"; value: Appearance.bar.radius; onMoved: (v) => Config.set("bar.radius", v) } }
        SetRow { title: "Espace entre modules"; SetSlider { implicitWidth: 300; from: 0; to: 16; suffix: " px"; value: Appearance.bar.gap; onMoved: (v) => Config.set("bar.gap", v) } }
        SetRow { title: "Marge intérieure des pilules"; SetSlider { implicitWidth: 300; from: 0; to: 20; suffix: " px"; value: Appearance.bar.pillPad; onMoved: (v) => Config.set("bar.pill_padding", v) } }
        SetRow { title: "Marge en haut"; SetSlider { implicitWidth: 300; from: 0; to: 20; suffix: " px"; value: Appearance.bar.topMargin; onMoved: (v) => Config.set("bar.top_margin", v) } }
        SetRow { title: "Marges sur les côtés"; SetSlider { implicitWidth: 300; from: 0; to: 60; suffix: " px"; value: Appearance.bar.sideMargin; onMoved: (v) => Config.set("bar.side_margin", v) } }
    }

    SetCard {
        title: "Horloge"
        SetRow {
            title: "Format"
            desc: "les secondes rafraîchissent l'horloge chaque seconde, sinon toutes les 15 s"
            SetSeg {
                options: [["HH:mm:ss", "20:12:45"], ["HH:mm", "20:12"], ["ddd HH:mm", "ven. 20:12"], ["dd/MM HH:mm", "17/10 20:12"]]
                current: String(Config.get("bar.clock_format", "HH:mm:ss"))
                onPicked: (v) => Config.set("bar.clock_format", v === "HH:mm:ss" ? null : v)
            }
        }
    }

    // Module en cours de déplacement, sous le pointeur
    Item {
        id: ghostHolder
        Layout.preferredHeight: 0
        z: 100
    Rectangle {
        readonly property point lp: ghostHolder.mapFromItem(page, page.dragPos.x, page.dragPos.y)
        visible: page.dragKey !== ""
        x: lp.x - 60; y: lp.y - page.chipH / 2
        width: 200; height: page.chipH; radius: 10
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.95)
        border.width: 1; border.color: Appearance.colors.accent
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            spacing: 8
            Text { text: page.dragKey ? BarModules.info(page.dragKey).ic : ""; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.accent }
            Text { Layout.fillWidth: true; text: page.dragKey ? BarModules.info(page.dragKey).name : ""; elide: Text.ElideRight
                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.fg }
        }
    }
    }
}
