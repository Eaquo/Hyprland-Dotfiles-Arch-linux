import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// NvmeCard — carte SSD NVMe : températures, débit (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    StatHeader { big: Math.round(SysData.nvmeT) + " °C"; col: SysData.tnvmeCol
             sub: "NVMe le plus chaud\nalerte " + SysData.nvmeAlert + " °C" }
    StatSpark { series: [[SysData.hist.tnvme, SysData.tnvmeCol, 90]] }
    Repeater {
        model: SysData.d ? SysData.d.temps.nvme.length : 0
        delegate: StatMeter {
            required property int index
            readonly property var e: SysData.d ? (SysData.d.temps.nvme[index] || ({ name: "", mount: "", temp: 0 })) : ({ name: "", mount: "", temp: 0 })
            readonly property var dk: SysData.d && e.mount ? SysData.d.disks.find(x => x.mount === e.mount) : null
            name: (e.mount ? SysData.mountName(e.mount) : e.name) + "  ·  " + e.name + (dk ? "  ·  " + dk.pct + " % plein" : "")
            value: Math.round(e.temp) + " °C"
            pct: (e.temp - 25) / 60 * 100
            col: SysData.lvl(e.temp, SysData.nvmeAlert - 10, SysData.nvmeAlert, Appearance.colors.color15)
        }
    }
    StatMeter { name: "Débit lecture · écriture"; value: SysData.mbs(SysData.d ? SysData.d.io.rd : 0) + " · " + SysData.mbs(SysData.d ? SysData.d.io.wr : 0)
                pct: Math.min(100, (SysData.d ? SysData.d.io.rd + SysData.d.io.wr : 0) / 10485760); col: Appearance.colors.color14 }
    StatHint { visible: hints; text: "clic : capteurs NVMe · clic droit : seuil d'alerte, santé SMART" }
}
