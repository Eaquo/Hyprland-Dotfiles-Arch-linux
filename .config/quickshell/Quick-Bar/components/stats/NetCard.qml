import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// NetCard — carte réseau : débit descendant / montant de l'interface par défaut, courbe.
ColumnLayout {
    property bool hints: true
    readonly property real peak: Math.max(131072, ...SysData.hist.rx, ...SysData.hist.tx)
    spacing: 6
    StatHeader { big: SysData.rate(SysData.net.rx); col: Appearance.colors.color14
                 sub: (SysData.net.iface || "hors ligne") + "\n↑ " + SysData.rate(SysData.net.tx) }
    StatSpark { series: [[SysData.hist.rx, Appearance.colors.color14, parent.peak], [SysData.hist.tx, Appearance.colors.color13, parent.peak]] }
    Text {
        text: "<font color='" + Appearance.colors.color14 + "'>●</font> réception    <font color='" + Appearance.colors.color13 + "'>●</font> envoi"
        textFormat: Text.StyledText
        font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
    }
    StatMeter { name: "Réception"; value: SysData.rate(SysData.net.rx); pct: SysData.net.rx / parent.peak * 100; col: Appearance.colors.color14 }
    StatMeter { name: "Envoi"; value: SysData.rate(SysData.net.tx); pct: SysData.net.tx / parent.peak * 100; col: Appearance.colors.color13 }
    StatHint { visible: hints; text: "clic : nload" }
}
