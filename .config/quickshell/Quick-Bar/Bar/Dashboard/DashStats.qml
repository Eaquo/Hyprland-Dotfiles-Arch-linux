import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../Common/"
import "../Common/functions/"
import "../Services/"

// DashStats — page System du popup Dashboard, refaite façon TouchStats : cartes
// glowy + jauges circulaires custom (Canvas), couleurs wallust. Disques simplifiés
// (barres en couleurs wallust différentes par disque).
Item {
    id: root
    readonly property int gap: 12

    // Palette wallust pour varier les couleurs (disques, etc.).
    readonly property var _wpal: [
        Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,
        Appearance.colors.color9,  Appearance.colors.color13, Appearance.colors.color2,
        Appearance.colors.color14, Appearance.colors.color12
    ]

    CpuService     { id: cpu;     active: root.visible }
    CpuFreqService { id: cpuFreq }
    MemService     { id: mem;     active: root.visible }
    GpuService     { id: gpu;     active: root.visible }
    ThermalService { id: thermal; active: root.visible }
    NetService     { id: net;     active: root.visible }
    DiskService    { id: disk;    active: root.visible }
    FanControl     { id: fan }

    function tempCol(t) {
        if (t <= 0)  return Appearance.colors.dim
        if (t < 50)  return "#89dceb"
        if (t < 70)  return "#a6e3a1"
        if (t < 82)  return "#f9e2af"
        if (t < 90)  return "#fab387"
        return "#f38ba8"
    }

    component GlowCard: Item {
        id: gcard
        property color glow: Appearance.colors.accent
        default property alias content: inner.data
        // Fond + ombre portés par un rectangle dédié → chiffres nets, pas de halo.
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
            border.color: ColorUtils.applyAlpha(gcard.glow, 0.28)
            border.width: 1
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: ColorUtils.applyAlpha(gcard.glow, 0.30)
                shadowBlur: 0.35
                shadowVerticalOffset: 4
            }
        }
        Item { id: inner; anchors { fill: parent; margins: 14 } }
    }

    // ── Cellule numérique iCUE : gros chiffre + unité, min/max ▲▼, waveform ──
    component MetricCell: Item {
        id: mc
        property string label: ""
        property color  col: Appearance.colors.accent
        property real   value: 0
        property string unit: ""
        property int    decimals: 0
        property string rightText: ""
        property var    hist: []
        property int    maxPts: 46
        property int    bigSize: 34
        property color  valueColor: Appearance.colors.fg
        property string valueText: ""

        readonly property real vmin: hist.length ? Math.min.apply(Math, hist) : value
        readonly property real vmax: hist.length ? Math.max.apply(Math, hist) : value

        Timer {
            interval: 1000; running: mc.visible; repeat: true
            onTriggered: {
                var h = mc.hist.slice(); h.push(mc.value)
                if (h.length > mc.maxPts) h.shift()
                mc.hist = h; spark.requestPaint()
            }
        }

        Canvas {
            id: spark
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var W = width, H = height
                var pts = mc.hist
                if (pts.length < 2) return
                var lo = mc.vmin, hi = mc.vmax; if (hi - lo < 1) hi = lo + 1
                var gy = H * 0.99, gh = H * 0.5
                ctx.beginPath()
                for (var i = 0; i < pts.length; i++) {
                    var xx = W * i / (mc.maxPts - 1)
                    var yy = gy - gh * ((pts[i] - lo) / (hi - lo))
                    if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy)
                }
                ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.shadowColor = mc.col; ctx.shadowBlur = 6
                ctx.strokeStyle = Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.7); ctx.stroke()
                ctx.shadowBlur = 0
                var lastX = W * (pts.length - 1) / (mc.maxPts - 1)
                ctx.lineTo(lastX, gy); ctx.lineTo(0, gy); ctx.closePath()
                var fgd = ctx.createLinearGradient(0, gy - gh, 0, gy)
                fgd.addColorStop(0, Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.18))
                fgd.addColorStop(1, Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.0))
                ctx.fillStyle = fgd; ctx.fill()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Text {
            anchors { top: parent.top; left: parent.left }
            text: mc.label
            font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold
            color: mc.col
        }
        Text {
            anchors { top: parent.top; right: parent.right }
            text: mc.rightText
            font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
        }

        Text {
            id: bigNum
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
            text: mc.valueText !== "" ? mc.valueText : mc.value.toFixed(mc.decimals)
            font.family: Appearance.font.family; font.pixelSize: mc.bigSize; font.weight: Font.Bold
            color: mc.valueColor
        }
        Text {
            anchors { left: bigNum.right; leftMargin: 3; baseline: bigNum.baseline }
            text: mc.unit
            font.family: Appearance.font.family; font.pixelSize: Math.round(mc.bigSize * 0.35); font.weight: Font.Bold
            color: mc.col
        }
        Text {
            visible: mc.valueText === ""
            anchors { left: parent.left; top: bigNum.bottom; topMargin: -2 }
            text: "▲ " + mc.vmax.toFixed(mc.decimals) + "   ▼ " + mc.vmin.toFixed(mc.decimals)
            font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.dim
        }
    }

    component CardHead: Item {
        property string label: ""
        property string rval: ""
        property color  rightCol: Appearance.colors.dim
        property color  labelCol: Appearance.colors.accent
        implicitHeight: 20
        width: parent ? parent.width : 0
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold
            color: parent.labelCol
        }
        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: parent.rval
            font.family: "JetBrains Mono"; font.pixelSize: 12; font.weight: Font.Bold
            color: parent.rightCol
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: root.gap
        spacing: root.gap

        // ══ Rangée héros : CPU · RAM · GPU ══
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color4
                MetricCell {
                    anchors.fill: parent
                    label: "CPU"; col: Appearance.colors.color4
                    value: cpu.usagePercent; unit: "%"
                    rightText: Math.round(thermal.cpuTemp) + "°"
                }
            }
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color5
                MetricCell {
                    anchors.fill: parent
                    label: "RAM"; col: Appearance.colors.color5
                    value: mem.usagePercent; unit: "%"
                    rightText: mem.usedStr + "/" + mem.totalStr
                }
            }
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color6
                MetricCell {
                    anchors.fill: parent
                    label: "GPU"; col: Appearance.colors.color6
                    value: gpu.igpu.freqPercent; unit: "%"
                    rightText: Math.round(thermal.gpuTemp) + "°"
                }
            }
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color9
                MetricCell {
                    anchors.fill: parent
                    label: "VRAM"; col: Appearance.colors.color9
                    value: gpu.igpu.vramPercent; unit: "%"
                    rightText: gpu.igpu.curMhz
                }
            }
        }

        // ══ Rangée : Temps · Disques · Réseau · Ventilos ══
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            // ── Températures ──
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: "#fab387"
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    MetricCell {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "CPU"; unit: "°"; value: thermal.cpuTemp
                        col: root.tempCol(thermal.cpuTemp); valueColor: root.tempCol(thermal.cpuTemp)
                    }
                    MetricCell {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "GPU"; unit: "°"; value: thermal.gpuTemp
                        col: root.tempCol(thermal.gpuTemp); valueColor: root.tempCol(thermal.gpuTemp)
                    }
                }
            }

            // ── Disques (simplifié : mount · barre couleur wallust · %) ──
            GlowCard {
                Layout.preferredWidth: 1.5; Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color3
                CardHead { id: dHead; anchors.top: parent.top; label: "Disques"; labelCol: Appearance.colors.color3 }
                ColumnLayout {
                    anchors { top: dHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 8 }
                    spacing: 0
                    Repeater {
                        model: disk.disks
                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            readonly property color dc: Qt.lighter(root._wpal[index % root._wpal.length], 1.2)
                            Layout.fillWidth: true; Layout.fillHeight: true
                            spacing: 10
                            Text {
                                Layout.preferredWidth: 56
                                text: modelData.mount; elide: Text.ElideRight
                                font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 8; radius: 4
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (modelData.usedPct || 0) / 100))
                                    height: parent.height; radius: parent.radius
                                    color: parent.parent.dc
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                            Text {
                                Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                                text: Math.round(modelData.usedPct || 0) + "%"
                                font.family: "JetBrains Mono"; font.pixelSize: 12; font.weight: Font.Bold
                                color: parent.dc
                            }
                        }
                    }
                }
            }

            // ── Réseau ──
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color2
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    MetricCell {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "↓ DOWN"; col: "#89b4fa"; bigSize: 20
                        value: net.downKbps; valueText: net.downSpeed; rightText: net.iface
                    }
                    MetricCell {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        label: "↑ UP"; col: "#a6e3a1"; bigSize: 20
                        value: net.upKbps; valueText: net.upSpeed
                    }
                }
            }

            // ── Ventilos ──
            GlowCard {
                Layout.fillWidth: true; Layout.fillHeight: true
                glow: Appearance.colors.color12
                CardHead {
                    id: fHead; anchors.top: parent.top; label: "Ventilateurs"
                    rval: thermal.fanCount > 0 ? thermal.fan1Str : ""
                    labelCol: Appearance.colors.color12
                }
                ColumnLayout {
                    anchors { top: fHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; topMargin: 6 }
                    spacing: 6
                    Item { Layout.fillHeight: true }
                    Repeater {
                        model: [ { m: "quiet", t: "Quiet" }, { m: "auto", t: "Auto" }, { m: "max", t: "Max" } ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: fan.mode === modelData.m
                            Layout.fillWidth: true; Layout.preferredHeight: 30
                            radius: 9
                            color: sel ? ColorUtils.applyAlpha(Appearance.colors.color12, 0.85)
                                      : ColorUtils.applyAlpha(Appearance.colors.bg, 0.4)
                            border.color: sel ? "transparent" : Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.t
                                font.family: Appearance.font.family; font.pixelSize: 12
                                font.weight: parent.sel ? Font.Bold : Font.Normal
                                color: parent.sel ? Appearance.colors.bg : Appearance.colors.fg
                            }
                            MouseArea { anchors.fill: parent; onClicked: fan.setMode(modelData.m) }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
