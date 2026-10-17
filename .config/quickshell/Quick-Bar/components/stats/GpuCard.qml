import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// GpuCard — carte GPU : températures, charge, VRAM, puissance, ventilateur (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    readonly property var g: SysData.d ? SysData.d.temps.gpu : ({})
    function c(v, warn, crit) { return SysData.lvl(v, warn, crit, Appearance.colors.color15) }
    StatHeader { big: Math.round(SysData.gpuT) + " °C"; col: SysData.tgpuCol
             sub: "GPU · junction\nalerte " + SysData.gpuAlert + " °C" }
    StatSpark { series: [[SysData.hist.tgpu, SysData.tgpuCol, 110]] }
    StatMeter { name: "Edge · junction"; value: Math.round(parent.g.edge || 0) + " · " + Math.round(parent.g.junction || 0) + " °C"
                pct: ((parent.g.junction || 0) - 30) / 80 * 100; col: SysData.tgpuCol }
    StatMeter { name: "Mémoire (VRAM)"; value: Math.round(parent.g.mem || 0) + " °C"
                pct: ((parent.g.mem || 0) - 30) / 80 * 100; col: parent.c(parent.g.mem || 0, 85, 100) }
    StatCaption { text: "Activité" }
    StatMeter { name: "Charge · " + Math.round(parent.g.sclk || 0) + " MHz"; value: (parent.g.busy || 0) + " %"
                pct: parent.g.busy || 0; col: Appearance.colors.color13 }
    StatMeter { name: "VRAM utilisée"; value: SysData.gb(parent.g.vramUsed || 0) + " / " + SysData.gb(parent.g.vramTotal || 1)
                pct: (parent.g.vramUsed || 0) / Math.max(1, parent.g.vramTotal || 1) * 100; col: Appearance.colors.color6 }
    StatMeter { name: "Consommation"; value: Math.round(parent.g.power || 0) + " / " + Math.round(parent.g.powerCap || 0) + " W"
                pct: (parent.g.power || 0) / Math.max(1, parent.g.powerCap || 1) * 100; col: Appearance.colors.color12 }
    StatMeter { name: "Ventilateur"; value: (parent.g.fan || 0) + " tr/min"
                pct: (parent.g.fan || 0) / 32; col: Appearance.colors.color14 }
    StatHint { visible: hints; text: "clic : amdgpu_top · clic droit : seuil d'alerte, nvtop, LACT" }
}
