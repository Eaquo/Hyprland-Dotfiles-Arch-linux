import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// CpuCard — carte CPU : charge, courbe, cœurs, processus (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    StatHeader { big: SysData.cpu + " %"; col: SysData.cpuCol
             sub: (SysData.d ? SysData.d.freq.toFixed(1).replace(".", ",") + " GHz · charge " + SysData.d.load.toFixed(2).replace(".", ",") : "") + (SysData.profile ? "\n" + SysData.profile : "") }
    StatSpark { series: [[SysData.hist.cpu, SysData.cpuCol, 100]] }
    StatCaption { text: (SysData.d ? SysData.d.cores.length : 0) + " threads" }
    Row {
        Layout.fillWidth: true; Layout.preferredHeight: 34
        spacing: 3
        Repeater {
            // Modèle = un nombre : les barres restent en place, seule leur hauteur s'anime
            model: SysData.d ? SysData.d.cores.length : 0
            delegate: Item {
                id: core
                required property int index
                readonly property int v: SysData.d ? (SysData.d.cores[index] || 0) : 0
                width: (parent.width - 3 * ((SysData.d ? SysData.d.cores.length : 1) - 1)) / Math.max(1, SysData.d ? SysData.d.cores.length : 1)
                height: 34
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; radius: 2
                    height: Math.max(3, parent.height * core.v / 100)
                    color: SysData.lvl(core.v, 50, 85, Appearance.colors.color13)
                    Behavior on height { NumberAnimation { duration: Appearance.dur(450); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Appearance.dur(300) } }
                }
            }
        }
    }
    StatCaption { text: "Plus gourmands" }
    Repeater {
        model: SysData.d && SysData.d.topCpu ? SysData.d.topCpu.length : 0
        delegate: StatMeter {
            required property int index
            readonly property var e: SysData.d && SysData.d.topCpu ? (SysData.d.topCpu[index] || ({ name: "", pct: 0 })) : ({ name: "", pct: 0 })
            name: e.name; value: e.pct.toFixed(1).replace(".", ",") + " %"
            // part de la charge actuelle : stable d'une mesure à l'autre
            pct: e.pct / Math.max(5, SysData.cpu) * 100; col: SysData.cpuCol
        }
    }
    StatHint { visible: hints; text: "clic : btop · clic droit : profil d'énergie, actions" }
}
