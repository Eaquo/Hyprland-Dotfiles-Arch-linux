import QtQuick
import "../Common/"
import "../Components/"
import "../Services/"
import "../Dashboard/"

// TouchStats — variante tactile (ultra-large) de la page System du Dashboard.
//
// Réutilise les mêmes panels (Speedometer, TempPanel, FanPanel, NetStatsPanel,
// DiskPanel, PowerPanel) en grille 4×2 qui remplit la largeur. Positionneurs
// simples Column/Row (pas QtQuick.Layouts) — sinon largeur auto-référente =
// boucle de binding qui effondre les cartes.
//
//  ┌────────┬────────┬────────┬──────────┐
//  │  CPU   │  RAM   │  GPU   │  Temps    │
//  ├────────┼────────┼────────┼──────────┤
//  │ Réseau │ Disques│Ventilos│  Alim     │
//  └────────┴────────┴────────┴──────────┘
Item {
    id: root
    readonly property int gap: 12

    CpuService     { id: cpu;     active: root.visible }
    MemService     { id: mem;     active: root.visible }
    NetService     { id: net;     active: root.visible }
    ThermalService { id: thermal; active: root.visible }
    FanControl     { id: fan }
    DiskService    { id: disk;    active: root.visible }
    CpuFreqService { id: cpuFreq }
    GpuService     { id: gpu;     active: root.visible }

    Column {
        anchors.fill: parent
        anchors.topMargin: root.gap
        spacing: root.gap

        readonly property real rowH: (height - anchors.topMargin - root.gap) / 2

        // ══ Rangée haute : jauges + températures ══
        Row {
            id: topRow
            width:  parent.width
            height: parent.rowH
            spacing: root.gap
            readonly property real cw: (width - root.gap * 3) / 4

            StatCard {
                width: topRow.cw; height: topRow.height
                Speedometer {
                    anchors.centerIn: parent
                    label: "CPU"; percent: cpu.usagePercent
                    centerText: cpu.usagePercent + "%"; bottomText: cpuFreq.curFreqStr
                    active: true; accentColor: Qt.lighter(Appearance.colors.color4, 1.15)
                }
            }
            StatCard {
                width: topRow.cw; height: topRow.height
                Speedometer {
                    anchors.centerIn: parent
                    label: "RAM"; percent: mem.usagePercent
                    centerText: mem.usagePercent + "%"; bottomText: mem.usedStr + " / " + mem.totalStr
                    active: true; accentColor: Qt.lighter(Appearance.colors.color5, 1.15)
                }
            }
            StatCard {
                width: topRow.cw; height: topRow.height
                Speedometer {
                    anchors.centerIn: parent
                    label: "GPU"; percent: gpu.igpu.freqPercent
                    centerText: gpu.igpu.freqPercent + "%"; bottomText: gpu.igpu.curMhz
                    active: true; accentColor: Qt.lighter(Appearance.colors.color6, 1.15)
                }
            }
            StatCard {
                width: topRow.cw; height: topRow.height
                padding: 6
                TempPanel {
                    anchors.fill: parent
                    service: thermal
                    dgpuActive: gpu.dgpu.active
                }
            }
        }

        // ══ Rangée basse : réseau · disques · ventilos · alim ══
        Row {
            id: botRow
            width:  parent.width
            height: parent.rowH
            spacing: root.gap
            readonly property real aw: width - root.gap * 3

            StatCard {
                width: botRow.aw * 0.22; height: botRow.height
                NetStatsPanel { anchors.fill: parent; service: net }
            }
            StatCard {
                width: botRow.aw * 0.34; height: botRow.height
                DiskPanel { anchors.fill: parent; service: disk }
            }
            StatCard {
                width: botRow.aw * 0.20; height: botRow.height
                padding: 6
                FanPanel { anchors.fill: parent; service: fan }
            }
            StatCard {
                width: botRow.aw * 0.24; height: botRow.height
                PowerPanel { anchors.fill: parent; cpuFreqService: cpuFreq }
            }
        }
    }
}
