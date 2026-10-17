import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.components
import qs.core
import qs.core.functions

// ThemePage — Réglages › Apparence › Thème : préréglages, accent, bordures animées, arrondis ([theme], [bar]).
ColumnLayout {
    id: page
    spacing: 18

    // Valeur absente de la config = valeur par défaut (null efface la clé)
    readonly property var presets: [
        { name: Appearance.paletteName, desc: "l'original", v: { "theme.accent": null, "theme.radius": null, "bar.radius": null, "theme.animated_borders": null, "theme.border_speed": null, "bar.separators": null } },
        { name: "Néon", desc: "accent vif, contour rapide", v: { "theme.accent": "color13", "theme.radius": 14, "bar.radius": 12, "theme.animated_borders": null, "theme.border_speed": 2, "bar.separators": null } },
        { name: "Minimal", desc: "sans contour ni traits", v: { "theme.accent": null, "theme.radius": 10, "bar.radius": 8, "theme.animated_borders": false, "theme.border_speed": null, "bar.separators": false } },
        { name: "Doux", desc: "très arrondi, contour lent", v: { "theme.accent": "color12", "theme.radius": 24, "bar.radius": 20, "theme.animated_borders": null, "theme.border_speed": 0.5, "bar.separators": null } }
    ]
    function isActive(p) {
        for (const k in p.v) {
            const cur = Config.get(k, null)
            if (cur !== p.v[k]) return false
        }
        return true
    }
    function apply(p) { for (const k in p.v) Config.set(k, p.v[k]) }

    PageHeader { title: "Thème"; sub: "[theme] accent · radius · animated_borders · border_speed dans config.toml" }

    SetCard {
        title: "Préréglages"
        GridLayout {
            Layout.fillWidth: true
            columns: 4; columnSpacing: 12; rowSpacing: 12
            Repeater {
                model: page.presets
                delegate: Rectangle {
                    id: pr
                    required property var modelData
                    readonly property bool on: page.isActive(modelData)
                    readonly property var v: modelData.v
                    // valeurs que le préréglage donnerait
                    readonly property color acc: Appearance._palette[v["theme.accent"] || "color11"] || Appearance.colors.accent
                    readonly property real r: v["theme.radius"] ?? 17
                    Layout.fillWidth: true
                    implicitHeight: 150
                    radius: 14
                    color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.10) : (prMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent")
                    border.width: on ? 2 : 1
                    border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(160) } }

                    // mini panneau
                    Rectangle {
                        id: mini
                        x: 14; y: 14; width: parent.width - 28; height: 78
                        radius: pr.r * 0.7
                        color: Appearance.colors.bg
                        border.width: pr.v["theme.animated_borders"] === false ? 1 : 0
                        border.color: Appearance.outline
                        GradientBorder {
                            anchors.fill: parent; radius: parent.radius; borderWidth: 2
                            visible: pr.v["theme.animated_borders"] !== false && Appearance.borderSpeed > 0
                        }
                        Rectangle { x: 12; y: 12; width: 26; height: 26; radius: Math.min(13, pr.r * 0.5); color: pr.acc }
                        Rectangle { x: 46; y: 15; width: parent.width - 64; height: 7; radius: 3; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.55) }
                        Rectangle { x: 46; y: 28; width: (parent.width - 64) * 0.6; height: 6; radius: 3; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25) }
                        Rectangle { x: 12; y: 50; width: parent.width - 24; height: 16; radius: Math.min(8, pr.r * 0.4)
                                    color: ColorUtils.applyAlpha(pr.acc, 0.25)
                                    Rectangle { width: parent.width * 0.62; height: parent.height; radius: parent.radius; color: pr.acc } }
                    }
                    Column {
                        x: 14; anchors { top: mini.bottom; topMargin: 10 }
                        spacing: 1
                        Text { text: pr.modelData.name + (pr.on ? "  ✓" : ""); font.family: Appearance.font.family; font.pixelSize: Appearance.font.small
                               font.weight: Font.DemiBold; color: pr.on ? Appearance.colors.accent : Appearance.colors.fg }
                        Text { text: pr.modelData.desc; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.dim }
                    }
                    MouseArea { id: prMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.apply(pr.modelData) }
                }
            }
        }
        Text {
            text: page.presets.some(p => page.isActive(p)) ? "" : "Thème personnalisé — clique un préréglage pour repartir de lui."
            visible: text !== ""
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
    }

    SetCard {
        title: "Couleur d'accent"
        SetRow {
            title: "Teinte de la palette"
            desc: "Boutons actifs, curseurs, animations. Elle suit la palette quand le fond d'écran change."
                  + (Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3 ? "\n⚠ Peu lisible sur le fond actuel." : "")
            Row {
                spacing: 6
                Repeater {
                    model: 15
                    delegate: Rectangle {
                        id: sw
                        required property int index
                        readonly property string slot: "color" + (index + 1)
                        readonly property bool on: Appearance.accentSlot === slot
                        width: 26; height: 26; radius: 8
                        color: Appearance._palette[slot] || "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                        scale: on ? 1.15 : (swMa.containsMouse ? 1.08 : 1)
                        Behavior on scale { NumberAnimation { duration: Appearance.dur(140); easing.type: Easing.OutBack } }
                        MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.set("theme.accent", sw.slot === "color11" ? null : sw.slot) }
                    }
                }
            }
        }
    }

    // ── Thème d'icônes du système (GTK 3/4, gsettings, qt5ct/qt6ct) ──
    readonly property string iconScript: Quickshell.shellDir + "/scripts/system/icon_themes.py"
    property var iconThemes: []
    property string iconCurrent: ""
    property string iconPending: ""
    Process {
        id: iconList
        running: true
        command: ["python3", page.iconScript, "list"]
        stdout: StdioCollector { onStreamFinished: { try { const j = JSON.parse(text); page.iconThemes = j.themes; page.iconCurrent = j.current } catch (e) {} } }
    }
    Process {
        id: iconApply
        onExited: { page.iconCurrent = page.iconPending; page.iconPending = ""; IconUtils.reload(); Config.saved() }
    }
    function applyIcons(id) {
        if (iconApply.running || id === iconCurrent) return
        iconPending = id
        iconApply.command = ["python3", iconScript, "apply", id]
        iconApply.running = true
    }

    SetCard {
        title: "Thème d'icônes du système"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Comme nwg-look : appliqué aux applis GTK 3/4 et Qt (qt5ct/qt6ct) et à la barre. Certaines applis déjà ouvertes ne changent qu'au redémarrage."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: page.iconThemes
                delegate: Rectangle {
                    id: it
                    required property var modelData
                    readonly property bool on: page.iconCurrent === modelData.id
                    readonly property bool busy: page.iconPending === modelData.id
                    Layout.fillWidth: true
                    implicitHeight: 92; radius: 12
                    color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.10) : (itMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent")
                    border.width: on ? 2 : 1
                    border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: it.modelData.name; elide: Text.ElideRight
                                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; font.weight: Font.DemiBold
                                   color: it.on ? Appearance.colors.accent : Appearance.colors.fg }
                            Text { text: it.busy ? "application…" : it.on ? "✓ actif" : ""
                                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.accent }
                        }
                        Row {
                            spacing: 8
                            Repeater {
                                model: it.modelData.preview
                                delegate: Image {
                                    required property string modelData
                                    width: 34; height: 34
                                    source: modelData ? "file://" + modelData : ""
                                    sourceSize: Qt.size(68, 68); smooth: true; mipmap: true
                                    asynchronous: true
                                }
                            }
                        }
                    }
                    MouseArea { id: itMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.applyIcons(it.modelData.id) }
                }
            }
        }
    }

    SetCard {
        title: "Icônes des applications (barre, en haut à droite)"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Steam, OpenRGB, Discord… dans la zone de notification. Clique un style ; l'aperçu montre tes applis ouvertes."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 5; columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: [["color", "Couleur", "d'origine"], ["mono", "Monochrome", "couleur du texte"], ["accent", "Accent", "couleur d'accent"],
                        ["gray", "Gris", "désaturées"], ["symbolic", "Symbolique", "icônes du thème"]]
                delegate: Rectangle {
                    id: ts
                    required property var modelData
                    readonly property bool on: Appearance.trayIcons === modelData[0]
                    Layout.fillWidth: true
                    implicitHeight: 96; radius: 12
                    color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.10) : (tsMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent")
                    border.width: on ? 2 : 1
                    border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                    // mini pilule de la barre avec les vraies icônes
                    Rectangle {
                        id: pill
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                        height: 30; width: Math.min(parent.width - 16, icons.implicitWidth + 16); radius: 15
                        color: Appearance.colors.bg; border.width: 1; border.color: Appearance.outline
                        clip: true
                        Row {
                            id: icons
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    required property var modelData
                                    width: 18; height: 18
                                    Image {
                                        id: im
                                        anchors.fill: parent
                                        source: IconUtils.resolve(parent.modelData.icon, "application-x-executable", ts.modelData[0] === "symbolic")
                                        sourceSize: Qt.size(36, 36); smooth: true; mipmap: true
                                        visible: ts.modelData[0] === "color"
                                    }
                                    MultiEffect {
                                        anchors.fill: im; source: im
                                        visible: ts.modelData[0] !== "color"
                                        saturation: ts.modelData[0] === "gray" ? -1 : 0
                                        brightness: ts.modelData[0] === "gray" ? 0 : 1
                                        colorization: ts.modelData[0] === "gray" ? 0 : 1
                                        colorizationColor: ts.modelData[0] === "accent" ? Appearance.colors.accent : Appearance.colors.fg
                                    }
                                }
                            }
                        }
                    }
                    Column {
                        anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom; topMargin: 8 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ts.modelData[1] + (ts.on ? "  ✓" : "")
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; font.weight: Font.DemiBold
                               color: ts.on ? Appearance.colors.accent : Appearance.colors.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ts.modelData[2]
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 5; color: Appearance.colors.dim }
                    }
                    MouseArea { id: tsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Config.set("theme.tray_icons", ts.modelData[0] === "color" ? null : ts.modelData[0]) }
                }
            }
        }
    }

    SetCard {
        title: "Bordures animées"
        SetRow {
            title: "Contour en dégradé"
            desc: "le contour coloré qui défile autour de la barre et des panneaux"
            SetSwitch { on: Appearance.animationsEnabled; onToggled: Config.set("theme.animated_borders", on ? false : null) }
        }
        SetRow {
            title: "Vitesse"
            desc: "0 = dégradé fixe (aucun rafraîchissement, le plus économe)"
            SetSlider { implicitWidth: 300; from: 0; to: 3; step: 0.25; decimals: 2; suffix: " ×"
                        value: Appearance.borderSpeed; onMoved: (v) => Config.set("theme.border_speed", v === 1 ? null : v) }
        }
    }

    SetCard {
        title: "Formes"
        SetRow { title: "Arrondi des panneaux"; desc: "dashboard, réglages, popups"
            SetSlider { implicitWidth: 300; from: 0; to: 30; suffix: " px"; value: Appearance.cornerRadius; onMoved: (v) => Config.set("theme.radius", v === 17 ? null : v) } }
        SetRow { title: "Arrondi de la barre"
            SetSlider { implicitWidth: 300; from: 0; to: 24; suffix: " px"; value: Appearance.bar.radius; onMoved: (v) => Config.set("bar.radius", v === 16 ? null : v) } }
    }
}
