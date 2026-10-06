import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../Common/"
import "../Common/functions/"

// MixerTab — mixeur tactile (TouchPanel) : une tranche verticale par app qui
// joue du son (streams PipeWire) + une tranche Master, et le choix de la sortie
// à droite. Glisser sur une tranche = volume, tap sur l'icône 󰖁 = muet.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    // Streams de LECTURE (Spotify, jeux, navigateur…) ; les captures (cava,
    // micros) ont isSink=false → exclues. Même règle que EqDash.
    readonly property var appStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    // Sorties physiques (Scarlett, Bose…) : sinks audio qui ne sont pas des streams.
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    PwObjectTracker { objects: root.appStreams.concat(root.outputs) }

    function appName(n) {
        const p = n.properties
        return (p && (p["application.name"] || p["media.name"])) || n.description || n.name || "App"
    }
    function appIcon(n) {
        const p = n.properties || {}
        const name = p["application.icon-name"] || DesktopEntries.heuristicLookup(p["application.name"] || "")?.icon
                     || (p["application.process.binary"] || "")
        return Quickshell.iconPath(name || "audio-volume-high", "audio-volume-high")
    }

    // ── Tranche de volume (verticale, tactile) ────────────────────────────────
    component Strip: Rectangle {
        id: strip
        property var node
        property string label
        property string icon: ""
        property string glyph: ""
        property color tint: Appearance.colors.accent
        readonly property real vol: node?.audio ? node.audio.volume : 0
        readonly property bool muted: node?.audio ? node.audio.muted : false

        implicitWidth: 150
        Layout.fillHeight: true
        radius: 20
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
        border.width: 1; border.color: ColorUtils.applyAlpha(strip.tint, 0.35)

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: strip.muted ? "muet" : Math.round(strip.vol * 100) + "%"
                font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold
                color: strip.muted ? Appearance.colors.dim : Appearance.colors.fg
            }

            // Piste : remplissage depuis le bas + poignée
            Rectangle {
                id: track
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                width: 64; radius: 18
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: Math.min(1, strip.vol) * parent.height
                    radius: 18
                    color: strip.muted ? ColorUtils.applyAlpha(strip.tint, 0.3) : strip.tint
                    Behavior on height { NumberAnimation { duration: 80 } }
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function set(m) {
                        if (!strip.node?.audio) return
                        strip.node.audio.volume = Math.max(0, Math.min(1, 1 - m.y / height))
                        GameBreak.extend()
                    }
                    onPressed: (m) => set(m)
                    onPositionChanged: (m) => set(m)
                }
            }

            // Icône (tap = muet)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64; height: 64; radius: 18
                color: strip.muted ? ColorUtils.applyAlpha(Appearance.colors.red, 0.8)
                                   : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                Image {
                    anchors.centerIn: parent
                    visible: strip.icon !== "" && !strip.muted
                    width: 40; height: 40; sourceSize: Qt.size(40, 40)
                    source: strip.icon
                }
                Text {
                    anchors.centerIn: parent
                    visible: strip.icon === "" || strip.muted
                    text: strip.muted ? "󰖁" : strip.glyph
                    font.family: Appearance.font.family; font.pixelSize: 30
                    color: strip.muted ? Appearance.colors.bg : strip.tint
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (strip.node?.audio) { strip.node.audio.muted = !strip.node.audio.muted; GameBreak.extend() }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: strip.label
                font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Medium
                color: Appearance.colors.fg
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // Master (sortie par défaut)
        Strip {
            node: root.sink
            label: "Master"
            glyph: "󰕾"
            tint: Appearance.colors.accent
        }

        Rectangle { Layout.fillHeight: true; width: 2; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }

        // Applications (défilable si beaucoup)
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: appRow.width
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentWidth > width

            Row {
                id: appRow
                height: parent.height
                spacing: 16
                Repeater {
                    model: root.appStreams
                    delegate: Strip {
                        required property var modelData
                        required property int index
                        height: appRow.height
                        node: modelData
                        label: root.appName(modelData)
                        icon: root.appIcon(modelData)
                        glyph: "󰝚"
                        tint: Appearance.legiblePalette[index % Appearance.legiblePalette.length]
                    }
                }
            }

            Text {
                visible: root.appStreams.length === 0
                anchors.centerIn: parent
                text: "Aucune application ne joue de son"
                font.family: Appearance.font.family; font.pixelSize: 20
                color: Appearance.colors.dim
            }
        }

        // ══ Sortie audio ══
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.minimumWidth: 360; Layout.maximumWidth: 360
            spacing: 12

            Text {
                text: "Sortie"
                font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold
                color: Appearance.colors.fg
            }
            Repeater {
                model: root.outputs
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.sink === modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 18
                    color: active ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                  : ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    // Easy Effects Sink = chemin AVEC l'égaliseur ; une sortie
                    // physique choisie directement le contourne.
                    readonly property bool isEq: (modelData.name || "").toLowerCase().indexOf("easyeffects") !== -1
                    Column {
                        anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text {
                            width: parent.width
                            text: parent.parent.isEq ? "󰓃  Avec égaliseur (EasyEffects)"
                                                     : (parent.parent.modelData.description || parent.parent.modelData.name)
                            font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Medium
                            color: parent.parent.active ? Appearance.colors.bg : Appearance.colors.fg
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: !parent.parent.isEq
                            text: "direct — sans égaliseur"
                            font.family: Appearance.font.family; font.pixelSize: 14
                            color: parent.parent.active ? Appearance.colors.bg : Appearance.colors.dim
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { Pipewire.preferredDefaultAudioSink = parent.modelData; GameBreak.extend() }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
