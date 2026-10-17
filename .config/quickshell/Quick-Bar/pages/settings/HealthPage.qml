import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions
import qs.services

// HealthPage — Réglages › Système › Santé ([health] proxmox · skip · [[health.custom]] ; scripts/health/check.sh).
ColumnLayout {
    id: page
    spacing: 18

    // id de check.sh → libellé
    readonly property var checks: [
        ["openrgb", "OpenRGB (serveur)"], ["rgb", "Démon RGB"], ["easyeffects", "EasyEffects"], ["hy3", "Plugin hy3"],
        ["hyprpm", "Cache hyprpm"], ["wallust", "Wallust"], ["discord", "Pont Discord"], ["launcher", "Backend des jeux"],
        ["instances", "Instances en double"], ["proxmox", "Proxmox"]
    ]
    readonly property var skip: Config.get("health.skip", []) || []
    function toggle(id) {
        const s = skip.slice(), i = s.indexOf(id)
        if (i >= 0) s.splice(i, 1); else s.push(id)
        Config.set("health.skip", s.length ? s : null)
        rerun.restart()
    }
    Timer { id: rerun; interval: 500; onTriggered: Health.refresh() }

    PageHeader { title: "Santé"; sub: "[health] dans config.toml — bilan toutes les " + Math.round(Config.ms("health", 300) / 60000) + " min" }

    SetCard {
        title: "Bilan"
        SetRow {
            title: Health.busy ? "Vérification…" : (Health.failCount === 0 ? "Tout va bien" : Health.failCount + " problème(s)")
            desc: Health.rows.filter(r => !r.ok).map(r => r.label).join(" · ")
            SetButton { label: "󰑓  Vérifier maintenant"; onTap: Health.refresh() }
        }
    }
    SetCard {
        title: "Vérifications"
        Repeater {
            model: page.checks
            delegate: SetRow {
                id: hc
                required property var modelData
                readonly property var row: Health.rows.find(r => r.id === modelData[0])
                title: modelData[1]
                desc: page.skip.indexOf(modelData[0]) >= 0 ? "désactivée" : (row ? (row.ok ? "✓ " : "✗ ") + row.detail : "")
                SetSwitch { on: page.skip.indexOf(hc.modelData[0]) < 0; onToggled: page.toggle(hc.modelData[0]) }
            }
        }
    }
    // ── Vérifications de l'utilisateur ([[health.custom]]) ──
    readonly property var custom: Config.get("health.custom", []) || []
    readonly property var types: [
        ["process", "󰐥", "Processus", "nom du programme, ex. steam"],
        ["service", "󰒓", "Service", "unité systemd, ex. pipewire"],
        ["url",     "󰖟", "Site / URL", "https://…"],
        ["host",    "󰛳", "Machine", "IP ou nom, ex. 192.168.1.50"],
        ["port",    "󰒍", "Port", "hôte:port, ex. 192.168.1.200:22"],
        ["mount",   "󰋊", "Montage", "point de montage, ex. ~/NAS"],
        ["file",    "󰈔", "Fichier", "chemin d'un fichier ou dossier"],
        ["command", "󰆍", "Commande", "réussit si elle renvoie 0"]
    ]
    function typeInfo(t) { return types.find(x => x[0] === t) || types[0] }
    function saveCustom(l) { Config.set("health.custom", l.length ? l : null); rerun.restart() }
    property string newType: "process"
    property string testMsg: ""

    // Suggestions par type : scripts/health/suggest.py (applis, services, réseau, ports, montages…)
    property var sugg: ({})
    property string query: ""
    property string picked: ""           // cible de la suggestion choisie
    readonly property var shownSugg: (sugg[newType] || []).filter(x => query === ""
        || (x.name + " " + x.target + " " + x.detail).toLowerCase().includes(query.toLowerCase())).slice(0, 150)
    // même liste avec un en-tête avant chaque groupe
    readonly property var rows: {
        const out = []; let g = null
        for (const x of shownSugg) { if (x.group !== g) { g = x.group; out.push({ header: true, name: g }) } out.push(x) }
        return out
    }
    function loadSugg() { suggProc.running = false; suggProc.running = true }
    Process {
        id: suggProc
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/health/suggest.py"]
        stdout: StdioCollector { onStreamFinished: { try { page.sugg = JSON.parse(text) } catch (e) {} } }
    }
    function pick(x) {
        nameIn.text = x.name; targetIn.text = x.target; fixIn.text = x.fix || ""
        picked = x.target; testMsg = ""
    }
    Process {
        id: browse
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p !== "") { targetIn.text = p; if (nameIn.text === "") nameIn.text = p.split("/").pop() } } }
    }

    // Test d'une vérification avant de l'ajouter : check.sh avec uniquement elle
    Process {
        id: testProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text)[0]; page.testMsg = r ? (r.ok ? "✓ " : "✗ ") + r.detail : "?" } catch (e) { page.testMsg = "?" }
            }
        }
    }
    function entry() {
        const e = { name: nameIn.text.trim() || targetIn.text.trim(), type: newType, target: targetIn.text.trim() }
        if (fixIn.text.trim() !== "") e.fix = fixIn.text.trim()
        return e
    }
    function test() {
        if (targetIn.text.trim() === "") return
        testMsg = "Test…"
        testProc.command = ["bash", Quickshell.shellDir + "/scripts/health/check.sh"]
        testProc.environment = { QB_HEALTH_SKIP: checks.map(c => c[0]).join(" "), QB_HEALTH_CUSTOM: JSON.stringify([entry()]) }
        testProc.running = false; testProc.running = true
    }

    SetCard {
        title: "Mes vérifications"
        Text {
            visible: page.custom.length === 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Ajoute ce que tu veux surveiller : un programme, un service, un site, une machine du réseau, un port, un fichier ou une commande. Ça apparaît dans le bilan (et l'onglet Santé du tactile), avec une réparation si tu en donnes une."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        Repeater {
            model: page.custom
            delegate: Rectangle {
                id: cu
                required property var modelData
                required property int index
                readonly property var row: Health.rows.find(r => r.id === "custom" + (index + 1))
                readonly property var ti: page.typeInfo(modelData.type)
                Layout.fillWidth: true
                implicitHeight: 52; radius: 10
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
                border.width: 1
                border.color: cu.row && !cu.row.ok ? ColorUtils.applyAlpha(Appearance.colors.color1, 0.6) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 10
                    Rectangle { width: 8; height: 8; radius: 4
                                color: !cu.row ? Appearance.colors.dim : (cu.row.ok ? "#7ee2a8" : Appearance.colors.color1) }
                    Text { text: cu.ti[1]; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: cu.modelData.name
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg }
                        Text { Layout.fillWidth: true; elide: Text.ElideRight
                               text: cu.ti[2] + " · " + (cu.row ? cu.row.detail : cu.modelData.target) + (cu.modelData.fix ? "  · réparation : " + cu.modelData.fix : "")
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.dim }
                    }
                    SetButton { visible: !!cu.modelData.fix && !!cu.row && !cu.row.ok; label: Health.fixing === "custom" + (cu.index + 1) ? "…" : "Réparer"
                                onTap: Health.fix("custom" + (cu.index + 1)) }
                    SetButton { label: "󰆴"; onTap: { const l = page.custom.slice(); l.splice(cu.index, 1); page.saveCustom(l) } }
                }
            }
        }

        // ── Ajouter : un onglet par type, avec ses suggestions ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: addCol.implicitHeight + 24
            radius: 12; color: "transparent"
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.4)
            ColumnLayout {
                id: addCol
                x: 14; y: 12; width: parent.width - 28
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "󰐕  Ajouter une vérification"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
                           font.weight: Font.DemiBold; color: Appearance.colors.accent }
                    SetButton { label: suggProc.running ? "…" : "󰑓  Actualiser la liste"; onTap: page.loadSugg() }
                }
                // onglets des types
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: page.types
                        delegate: SetButton {
                            required property var modelData
                            readonly property int n: (page.sugg[modelData[0]] || []).length
                            label: modelData[1] + "  " + modelData[2] + (n ? "  " + n : "")
                            active: page.newType === modelData[0]
                            onTap: { page.newType = modelData[0]; page.testMsg = ""; page.query = ""; search.text = "" }
                        }
                    }
                }

                // suggestions du type
                SetInput { id: search; Layout.fillWidth: true; placeholder: "󰍉  Filtrer les suggestions…"; onTextChanged: page.query = text }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 250; radius: 10
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                    clip: true
                    ListView {
                        id: sl
                        anchors { fill: parent; margins: 4 }
                        model: page.rows
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 2
                        delegate: Rectangle {
                            id: sg
                            required property var modelData
                            readonly property bool on: !modelData.header && page.picked === modelData.target && targetIn.text === modelData.target
                            width: ListView.view.width; height: modelData.header ? 26 : 42; radius: 8
                            Text {
                                visible: !!sg.modelData.header
                                anchors { left: parent.left; leftMargin: 10; bottom: parent.bottom; bottomMargin: 4 }
                                text: sg.modelData.name
                                font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.5
                                font.capitalization: Font.AllUppercase; color: Appearance.colors.dim
                            }
                            color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.22) : sgMa.containsMouse && !modelData.header ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent"
                            RowLayout {
                                visible: !sg.modelData.header
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 10
                                Rectangle { visible: sg.modelData.active !== undefined; width: 7; height: 7; radius: 4
                                            color: sg.modelData.active ? "#7ee2a8" : Appearance.colors.dim }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: sg.modelData.name
                                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.fg }
                                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: sg.modelData.detail || ""
                                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 5; color: Appearance.colors.dim }
                                }
                                Text { Layout.maximumWidth: 260; elide: Text.ElideMiddle; text: sg.modelData.target || ""
                                       font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.accent }
                                Text { visible: !!sg.modelData.fix; text: "󰖷"; font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                            }
                            MouseArea { id: sgMa; anchors.fill: parent; enabled: !sg.modelData.header; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.pick(sg.modelData) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: page.shownSugg.length === 0
                        text: suggProc.running ? "Recherche…" : (page.query !== "" ? "Aucune suggestion — tape la cible ci-dessous" : "Pas de suggestion pour ce type — tape la cible ci-dessous")
                        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
                    }
                }
                Text { text: "󰖷 = réparation proposée · clique une ligne pour remplir le formulaire"
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 5; color: Appearance.colors.dim }

                // formulaire
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SetInput { id: nameIn; implicitWidth: 200; placeholder: "Nom affiché" }
                    SetInput { id: targetIn; Layout.fillWidth: true; placeholder: page.typeInfo(page.newType)[3]; onTextChanged: page.testMsg = "" }
                    SetButton {
                        visible: page.newType === "file" || page.newType === "mount"
                        label: "󰉋  Parcourir…"
                        onTap: {
                            browse.command = ["sh", "-c", page.newType === "mount"
                                ? "zenity --file-selection --directory --title='Point de montage' 2>/dev/null || kdialog --getexistingdirectory ~"
                                : "zenity --file-selection --title='Fichier à surveiller' 2>/dev/null || kdialog --getopenfilename ~"]
                            browse.running = false; browse.running = true
                        }
                    }
                }
                SetInput { id: fixIn; Layout.fillWidth: true; placeholder: "Réparation (facultatif) — commande lancée par « Réparer »" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { Layout.fillWidth: true; text: page.testMsg; elide: Text.ElideRight
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2
                           color: page.testMsg.startsWith("✓") ? "#7ee2a8" : page.testMsg.startsWith("✗") ? Appearance.colors.color1 : Appearance.colors.dim }
                    SetButton { label: "󰐊  Tester"; onTap: page.test() }
                    SetButton { label: "󰐕  Ajouter"; primary: true
                                onTap: { if (targetIn.text.trim() === "") return
                                         page.saveCustom(page.custom.concat([page.entry()]))
                                         nameIn.text = ""; targetIn.text = ""; fixIn.text = ""; page.testMsg = ""; page.picked = "" } }
                }
            }
        }
    }

    SetCard {
        title: "Proxmox"
        SetRow {
            title: "Adresse"; desc: "IP ou nom ; l'interface web (port 8006) doit répondre"
            SetInput { implicitWidth: 260; text: String(Config.get("health.proxmox", "")); placeholder: "192.168.1.200"
                       onCommitted: (t) => { Config.set("health.proxmox", t.trim() === "" ? null : t.trim()); rerun.restart() } }
        }
    }
}
