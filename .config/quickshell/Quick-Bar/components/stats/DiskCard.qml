import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// DiskCard — carte disques : place, débit, à récupérer (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    readonly property real ioMax: Math.max(1048576, ...SysData.hist.rd, ...SysData.hist.wr)
    StatHeader { big: SysData.diskPct + " %"; col: SysData.diskCol
             sub: SysData.rootDisk ? SysData.size(SysData.rootDisk.used) + " / " + SysData.size(SysData.rootDisk.size) : "" }
    StatSpark { series: [[SysData.hist.rd, Appearance.colors.color14, parent.ioMax], [SysData.hist.wr, Appearance.colors.color13, parent.ioMax]] }
    Text {
        text: "<font color='" + Appearance.colors.color14 + "'>●</font> lecture " + SysData.mbs(SysData.d ? SysData.d.io.rd : 0)
            + "    <font color='" + Appearance.colors.color13 + "'>●</font> écriture " + SysData.mbs(SysData.d ? SysData.d.io.wr : 0)
        textFormat: Text.StyledText
        font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
    }
    Repeater {
        model: SysData.d ? SysData.d.disks.length : 0
        delegate: StatMeter {
            required property int index
            readonly property var e: SysData.d ? (SysData.d.disks[index] || ({ mount: "", dev: "", avail: 0, pct: 0 })) : ({ mount: "", dev: "", avail: 0, pct: 0 })
            name: SysData.mountName(e.mount) + "  ·  " + e.dev
            value: SysData.size(e.avail) + " libres"
            pct: e.pct; col: SysData.lvl(e.pct, 75, 90, Appearance.colors.color14)
        }
    }
    StatCaption { text: "À récupérer"; visible: !!(SysData.d && SysData.d.reclaim && SysData.d.reclaim.pacman !== undefined) }
    StatMeter { visible: !!(SysData.d && SysData.d.reclaim && SysData.d.reclaim.trash !== undefined)
            name: "Corbeille"; value: SysData.d && SysData.d.reclaim ? SysData.size(SysData.d.reclaim.trash || 0) : ""
            pct: SysData.d && SysData.d.reclaim ? (SysData.d.reclaim.trash || 0) / 21474836480 * 100 : 0; col: Appearance.colors.color12 }
    StatMeter { visible: !!(SysData.d && SysData.d.reclaim && SysData.d.reclaim.pacman !== undefined)
            name: "Cache pacman"; value: SysData.d && SysData.d.reclaim ? SysData.size(SysData.d.reclaim.pacman || 0) : ""
            pct: SysData.d && SysData.d.reclaim ? (SysData.d.reclaim.pacman || 0) / 21474836480 * 100 : 0; col: Appearance.colors.color12 }
    StatHint { visible: hints; text: "clic : ncdu · clic milieu : utilisé ↔ libre · clic droit : nettoyer" }
}
