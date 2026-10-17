import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// DepsPage — Réglages › Système › Dépendances.
// Données : scripts/system/deps.py (registre unique, une ligne par dépendance).
ColumnLayout {
    id: page
    spacing: 18

    property var deps: []
    property var distro: ({ name: "", familyName: "", known: true })
    property string installCmd: ""
    property var manual: []
    property bool busy: false
    property bool onlyMissing: false
    readonly property var missing: deps.filter(d => !d.ok)
    readonly property var groups: {
        const g = []
        for (const d of deps) if (!g.some(x => x.name === d.group)) g.push({ name: d.group, required: d.required })
        return g
    }

    function check() { busy = true; proc.running = false; proc.running = true }
    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/system/deps.py"]
        stdout: StdioCollector { onStreamFinished: {
            try { const j = JSON.parse(text); page.deps = j.deps; page.distro = j.distro; page.installCmd = j.install; page.manual = j.manual } catch (e) {}
            page.busy = false } }
    }
    Component.onCompleted: check()

    PageHeader { title: "Dépendances"
                 sub: (page.distro.name ? page.distro.name + " · paquets " + page.distro.familyName + (page.distro.known ? "" : " (distribution non reconnue, noms Arch)") + " · " : "")
                      + "scripts/system/deps.py" }

    // ── Bilan ──
    SetCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Canvas {
                id: ring
                Layout.preferredWidth: 68; Layout.preferredHeight: 68
                property real pct: page.deps.length ? (page.deps.length - page.missing.length) / page.deps.length : 0
                property real shown: 0
                Behavior on shown { NumberAnimation { duration: Appearance.dur(700); easing.type: Easing.OutCubic } }
                onPctChanged: shown = pct
                onShownChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d"); g.reset()
                    g.lineWidth = 7; g.lineCap = "round"
                    g.strokeStyle = ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                    g.beginPath(); g.arc(34, 34, 28, 0, Math.PI * 2); g.stroke()
                    g.strokeStyle = page.missing.length ? Appearance.colors.color12 : Appearance.colors.accent
                    g.beginPath(); g.arc(34, 34, 28, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * shown); g.stroke()
                }
                Text { anchors.centerIn: parent; text: Math.round(ring.pct * 100) + "%"
                       font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold; color: Appearance.colors.fg }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: page.busy && !page.deps.length ? "Vérification…" : (page.deps.length - page.missing.length) + " / " + page.deps.length + " présents"
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.body + 1; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                       text: page.missing.length ? page.missing.length + " manquant(s) : " + page.missing.map(d => d.name).join(", ")
                                                 : "Tout est installé, Quick-Bar a tout ce qu'il lui faut."
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.dim }
            }
            SetButton { label: page.busy ? "Vérification…" : "󰑓  Revérifier"; onTap: page.check() }
            SetButton { label: "Manquants seulement"; active: page.onlyMissing; onTap: page.onlyMissing = !page.onlyMissing }
        }
    }

    // ── Commande d'installation (seulement s'il manque quelque chose) ──
    SetCard {
        visible: page.installCmd !== ""
        title: "Installer ce qui manque · " + page.distro.familyName
        Rectangle {
            Layout.fillWidth: true; implicitHeight: cmdTxt.implicitHeight + 20; radius: 9
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7)
            Text { id: cmdTxt; x: 12; y: 10; width: parent.width - 24; wrapMode: Text.WrapAnywhere
                   text: page.installCmd; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.color15 }
        }
        RowLayout {
            spacing: 8
            SetButton { label: "󰆏  Copier"; primary: true; onTap: { Quickshell.execDetached(["wl-copy", page.installCmd]); label = "Copié ✓" } }
            SetButton { label: "  Lancer dans un terminal"
                  onTap: Quickshell.execDetached(Config.term("Installer", ["sh", "-c", page.installCmd + "; echo; read -p 'Entrée pour fermer'"])) }
        }
    }

    // ── Ce qui n'est pas dans les dépôts de cette distribution ──
    SetCard {
        visible: page.manual.length > 0
        title: "À installer à la main"
        Repeater {
            model: page.manual
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true; spacing: 12
                Text { Layout.preferredWidth: 170; text: parent.modelData.name; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; color: Appearance.colors.fg }
                Text { Layout.fillWidth: true; text: parent.modelData.how; wrapMode: Text.WordWrap
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.dim }
            }
        }
    }

    // ── Groupes ──
    Repeater {
        model: page.groups
        delegate: SetCard {
            id: grpCard
            required property var modelData
            readonly property var items: page.deps.filter(d => d.group === modelData.name && (!page.onlyMissing || !d.ok))
            visible: items.length > 0
            title: modelData.name + (modelData.required ? "  ·  indispensable" : "  ·  optionnel")
            Repeater {
                model: grpCard.items
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: parent.modelData.ok ? "#7ee2a8" : Appearance.colors.color12
                    }
                    Text { Layout.preferredWidth: 170; text: parent.modelData.name; elide: Text.ElideRight
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; color: Appearance.colors.fg }
                    Text { Layout.preferredWidth: 190; text: parent.modelData.manual ? "hors dépôts" : parent.modelData.package; elide: Text.ElideRight
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.dim }
                    Text { Layout.fillWidth: true; text: parent.modelData.use; elide: Text.ElideRight
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.dim }
                    Text { text: parent.modelData.ok ? "ok" : "manquant"
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3
                           color: parent.modelData.ok ? Appearance.colors.dim : Appearance.colors.color12 }
                }
            }
        }
    }
}
