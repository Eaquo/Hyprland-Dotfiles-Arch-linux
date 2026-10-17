import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// RamCard — carte mémoire : utilisée/cache/libre, courbe, plus gros (survol de la barre, pages System).
ColumnLayout {
    // false = sans la ligne d'aide des clics de la barre
    property bool hints: true
    spacing: 6
    readonly property var m: SysData.d ? SysData.d.mem : ({ total: 1, used: 0, cache: 0, swapUsed: 0 })
    StatHeader { big: SysData.gb(SysData.memUsed); col: SysData.ramCol
             sub: "sur " + SysData.gb(parent.m.total) + "\nswap " + SysData.gb(parent.m.swapUsed) }
    Row {
        id: stack
        Layout.fillWidth: true; Layout.preferredHeight: 12; Layout.topMargin: 4
        spacing: 2
        readonly property real w: width - 4
        Rectangle { height: 12; radius: 3; color: SysData.ramCol; width: stack.w * parent.parent.m.used / parent.parent.m.total
                    Behavior on width { NumberAnimation { duration: Appearance.dur(450) } } }
        Rectangle { height: 12; radius: 3; color: ColorUtils.applyAlpha(SysData.ramCol, 0.35); width: stack.w * Math.min(parent.parent.m.cache, parent.parent.m.total - parent.parent.m.used) / parent.parent.m.total
                    Behavior on width { NumberAnimation { duration: Appearance.dur(450) } } }
        Rectangle { height: 12; radius: 3; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08); width: Math.max(0, stack.w - stack.children[0].width - stack.children[1].width) }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "utilisée · cache " + SysData.gb(parent.m.cache) + " · libre " + SysData.gb(Math.max(0, parent.m.total - parent.m.used - parent.m.cache))
        font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
    }
    StatSpark { series: [[SysData.hist.ram, SysData.ramCol, parent.m.total]] }
    StatCaption { text: "Plus gros" }
    Repeater {
        model: SysData.d && SysData.d.topMem ? SysData.d.topMem.length : 0
        delegate: StatMeter {
            required property int index
            readonly property var e: SysData.d && SysData.d.topMem ? (SysData.d.topMem[index] || ({ name: "", bytes: 0 })) : ({ name: "", bytes: 0 })
            name: e.name; value: SysData.gb(e.bytes)
            pct: e.bytes / SysData.memTotal * 100; col: SysData.ramCol
        }
    }
    StatHint { visible: hints; text: "clic milieu : Go ↔ % · clic droit : actions" }
}
