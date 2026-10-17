import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// CpuTempCard — carte température CPU : Tctl, CCD (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    readonly property var t: SysData.d ? SysData.d.temps.cpu : ({ tctl: 0, ccd: [] })
    StatHeader { big: Math.round(SysData.cpuT) + " °C"; col: SysData.tcpuCol
             sub: "CPU · Tctl\nalerte " + SysData.cpuAlert + " °C" }
    StatSpark { series: [[SysData.hist.tcpu, SysData.tcpuCol, 100]] }
    StatMeter { name: "Tctl (contrôle)"; value: Math.round(SysData.cpuT) + " °C"
                pct: (SysData.cpuT - 30) / 70 * 100; col: SysData.tcpuCol }
    Repeater {
        model: (parent.t.ccd || []).length
        delegate: StatMeter {
            required property int index
            readonly property real v: SysData.d ? (SysData.d.temps.cpu.ccd[index] || 0) : 0
            name: "CCD" + (index + 1) + " (cœurs " + (index * 6) + "–" + (index * 6 + 5) + ")"
            value: Math.round(v) + " °C"
            pct: (v - 30) / 70 * 100; col: SysData.lvl(v, SysData.cpuAlert - 12, SysData.cpuAlert, Appearance.colors.color15)
        }
    }
    StatMeter { name: "Charge · fréquence"; value: SysData.cpu + " % · " + (SysData.d ? SysData.d.freq.toFixed(1).replace(".", ",") : "0") + " GHz"
                pct: SysData.cpu; col: SysData.cpuCol }
    StatHint { visible: hints; text: "clic : sensors · clic droit : seuil d'alerte, profil d'énergie" }
}
