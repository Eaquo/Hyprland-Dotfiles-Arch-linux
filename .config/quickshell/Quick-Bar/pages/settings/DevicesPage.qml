import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.core
import qs.core.functions
import qs.services

// DevicesPage — Réglages › Panneaux › Périphériques : notifications de connexion, et photo de chaque
// périphérique détecté (connecté, déjà vu : ShellState.devicesSeen, ou listé dans assets/devices/devices.json).
// Photo depuis une fiche boutique Shopify (on choisit parmi ses images) ou depuis un fichier local ;
// tout passe par scripts/system/device-photos.py (set / file / rm / images).
ColumnLayout {
    id: page
    spacing: 18
    readonly property string script: Quickshell.shellDir + "/scripts/system/device-photos.py"

    // fiches enregistrées (devices.json) : préremplit l'adresse de chaque appareil
    property var shops: ({})
    FileView {
        path: Quickshell.shellDir + "/assets/devices/devices.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { page.shops = JSON.parse(text()) } catch (e) { page.shops = {} } }
    }

    // connectés d'abord, puis déjà vus, puis ceux de devices.json
    readonly property var rows: {
        const out = [], has = m => out.some(r => r.model === m)
        for (const d of Batteries.all) if (d.model && !has(d.model)) out.push({ model: d.model, type: d.type, dev: d })
        for (const s of (ShellState.devicesSeen || [])) if (!has(s.model)) out.push({ model: s.model, type: s.type, dev: null })
        for (const m of Object.keys(shops)) if (!m.startsWith("_") && !has(m)) out.push({ model: m, type: -1, dev: null })
        return out
    }

    PageHeader { title: "Périphériques"; sub: "[devices] dans config.toml · photos dans assets/devices/" }

    SetCard {
        title: "Notifications"
        resetKeys: ["devices.notify_connect", "devices.notify_disconnect"]
        SetRow {
            title: "À la connexion"; desc: "photo, type, liaison et batterie du périphérique"
            SetSwitch { on: Config.get("devices.notify_connect", true); onToggled: Config.set("devices.notify_connect", on ? false : null) }
        }
        SetRow {
            title: "À la déconnexion"; desc: "avec la dernière batterie connue"
            SetSwitch { on: Config.get("devices.notify_disconnect", true); onToggled: Config.set("devices.notify_disconnect", on ? false : null) }
        }
    }

    SetCard {
        title: "Photos"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Détectés automatiquement (sans fil sur batterie). Boutique : collez l'adresse d'une fiche produit "
                + "d'une boutique Shopify, puis touchez la photo voulue. Fichier : n'importe quelle image, détourée si "
                + "son fond est uni. « Fond enfermé » retire aussi le fond pris dans un arceau de casque."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        Text {
            visible: page.rows.length === 0
            text: "Aucun périphérique détecté pour l'instant : connectez-en un."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg
        }
        Repeater {
            model: page.rows
            delegate: DevRow { required property var modelData; info: modelData; Layout.fillWidth: true }
        }
    }

    component DevRow: ColumnLayout {
        id: row
        property var info
        property bool open: false
        property bool enclosed: false
        property var shots: []
        property string status: ""
        readonly property var shop: page.shops[info.model] || null
        spacing: 10

        // une commande du script à la fois ; recharge les images de toutes les pages en cas de succès
        property var after: null
        Process {
            id: job
            stdout: StdioCollector { id: jobOut }
            stderr: StdioCollector { id: jobErr }
            onExited: (code) => {
                if (code !== 0) { row.status = "󰅙 " + (jobErr.text.trim().split("\n").pop() || "échec"); return }
                row.status = ""
                if (row.after) row.after(jobOut.text.trim())
            }
        }
        function run(args, label, then) {
            status = label; after = then || (() => Batteries.photoRev++)
            job.command = ["python3", page.script].concat(args); job.running = true
        }
        Process {
            id: picker
            command: ["sh", "-c", "command -v zenity >/dev/null && exec zenity --file-selection --title='Photo du périphérique' "
                                + "--file-filter='Images | *.png *.jpg *.jpeg *.webp *.avif' || exec kdialog --getopenfilename ~ 'image/*'"]
            stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p !== "")
                                     row.run(["file", row.info.model, p].concat(row.enclosed ? ["tout"] : []), "détourage…") } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 64; Layout.preferredHeight: 64; radius: 32
                color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.12)
                Image {
                    id: thumb
                    anchors.fill: parent; anchors.margins: 6
                    source: Batteries.photo({ model: row.info.model })
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true
                    sourceSize.height: 128
                    visible: status === Image.Ready
                }
                Text { anchors.centerIn: parent; visible: thumb.status !== Image.Ready
                       text: row.info.type >= 0 ? Batteries.icon(row.info.type) : "󰂑"
                       font.family: Appearance.font.family; font.pixelSize: 26; color: Appearance.colors.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: row.info.model
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                Text { Layout.fillWidth: true; elide: Text.ElideRight
                       text: row.info.dev ? [Batteries.kind(row.info.type), Batteries.link(row.info.dev), Batteries.pct(row.info.dev) + " %"].filter(x => x).join(" · ")
                                          : (row.info.type >= 0 ? Batteries.kind(row.info.type) + " · " : "") + "non connecté"
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                Text { Layout.fillWidth: true; elide: Text.ElideMiddle
                       text: row.status !== "" ? row.status
                           : (thumb.status === Image.Ready ? "󰄬 " + Batteries.slug(row.info.model) + ".png" : "aucune photo")
                             + (row.shop ? " · boutique" : "")
                       font.family: "JetBrains Mono"; font.pixelSize: Appearance.font.small - 4
                       color: row.status.startsWith("󰅙") ? Appearance.colors.color4 : Appearance.colors.dim }
            }
            SetButton { label: "󰖟  Boutique"; active: row.open; onTap: row.open = !row.open }
            SetButton { label: "󰉋  Fichier"; onTap: picker.running = true }
            SetButton { label: "󰆴"; visible: thumb.status === Image.Ready || row.shop !== null
                        onTap: row.run(["rm", row.info.model], "suppression…") }
        }

        // choix sur une fiche boutique
        ColumnLayout {
            Layout.fillWidth: true; Layout.leftMargin: 78
            visible: row.open
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                SetInput { id: url; Layout.fillWidth: true; text: row.shop ? row.shop.url : ""
                           placeholder: "https://boutique…/products/…"
                           onCommitted: (t) => { if (t.trim() !== "") load.tap() } }
                Text { text: "Fond enfermé"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.dim }
                SetSwitch { on: row.enclosed; onToggled: row.enclosed = !row.enclosed }
                SetButton { id: load; label: "Charger les photos"; primary: true
                            onTap: row.run(["images", url.text.trim()], "lecture de la fiche…",
                                           (t) => row.shots = t.split("\n").filter(x => x !== "")) }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: row.shots
                    delegate: Rectangle {
                        id: shot
                        required property var modelData
                        required property int index
                        readonly property bool chosen: row.shop && row.shop.url === url.text.trim() && (row.shop.image || 0) === index
                        width: 96; height: 96; radius: 12; clip: true
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, sMa.containsMouse ? 0.14 : 0.06)
                        border.width: chosen ? 2 : 0; border.color: Appearance.colors.accent
                        // jamais d'https direct dans un Image (crash OpenSSL de Quickshell) : téléchargé par curl
                        CachedArt { id: art; url: shot.modelData + (shot.modelData.indexOf("?") < 0 ? "?" : "&") + "width=200" }
                        Image { anchors.fill: parent; anchors.margins: 4; source: art.local
                                fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize: Qt.size(192, 192) }
                        MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: row.run(["set", row.info.model, url.text.trim(), String(shot.index)].concat(row.enclosed ? ["tout"] : []),
                                                       "téléchargement…") }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) }
    }
}
