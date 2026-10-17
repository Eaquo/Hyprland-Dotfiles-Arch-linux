import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// GeneralPage — Réglages › Général : profil, applications, écrans ([general]).
ColumnLayout {
    id: page
    spacing: 18

    readonly property var terminals: ["kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "gnome-terminal", "ptyxis", "xterm"]
    property var installed: []
    Process {
        running: true
        command: ["sh", "-c", "for t in " + page.terminals.join(" ") + "; do command -v $t >/dev/null && echo $t; done"]
        stdout: StdioCollector { onStreamFinished: page.installed = text.trim().split("\n").filter(t => t !== "") }
    }
    // Sélecteur de fichier : zenity, sinon kdialog
    Process {
        id: picker
        command: ["sh", "-c", "command -v zenity >/dev/null && exec zenity --file-selection --title='Photo de profil' --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif' "
                            + "|| exec kdialog --getopenfilename ~ 'image/png image/jpeg image/webp image/gif'"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p !== "") Config.set("general.avatar", p) } }
    }

    PageHeader { title: "Général"; sub: "[general] dans config.toml" }

    SetCard {
        title: "Profil"
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Item {
                Layout.preferredWidth: 84; Layout.preferredHeight: 84
                Image {
                    id: av
                    anchors.fill: parent
                    source: "file://" + Config.avatar
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(168, 168)
                    visible: false
                }
                Rectangle { id: avMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: parent; source: av; maskEnabled: true; maskSource: avMask; visible: av.status === Image.Ready }
                Rectangle {
                    anchors.fill: parent; radius: width / 2; color: "transparent"
                    border.width: 2; border.color: Appearance.colors.accent
                    Text { anchors.centerIn: parent; visible: av.status !== Image.Ready; text: "󰀄"; font.family: Appearance.font.family; font.pixelSize: 34; color: Appearance.colors.dim }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                SetRow {
                    title: "Nom affiché"; desc: "vide = nom d'utilisateur (" + (Quickshell.env("USER") || "?") + ")"
                    SetInput { implicitWidth: 300; text: String(Config.get("general.name", "")); placeholder: Quickshell.env("USER") || ""
                               onCommitted: (t) => Config.set("general.name", t.trim() === "" ? null : t.trim()) }
                }
                SetRow {
                    title: "Photo de profil"
                    desc: av.status === Image.Error ? "⚠ image introuvable : " + Config.avatar : "accueil du dashboard et du panneau tactile"
                    RowLayout {
                        spacing: 8
                        SetInput { implicitWidth: 220; text: String(Config.get("general.avatar", "~/.face")); placeholder: "~/.face"
                                   onCommitted: (t) => Config.set("general.avatar", t === "" || t === "~/.face" ? null : t) }
                        SetButton { label: "󰉋  Choisir…"; onTap: { picker.running = false; picker.running = true } }
                    }
                }
            }
        }
    }

    SetCard {
        title: "Applications"
        SetRow {
            title: "Terminal"
            desc: "pour les actions de la barre : btop, capteurs, mises à jour, nmtui, éditeur…"
            RowLayout {
                spacing: 8
                SetSeg {
                    options: page.installed.map(t => [t, t])
                    current: Config.terminal
                    onPicked: (v) => Config.set("general.terminal", v === "kitty" ? null : v)
                }
                SetButton { label: "󰐊  Tester"; onTap: Quickshell.execDetached(Config.term("Quick-Bar", ["sh", "-c", "echo 'Terminal OK : " + Config.terminal + "'; sleep 3"])) }
            }
        }
        SetRow {
            title: "Autre terminal"; desc: "commande ou chemin, si absent de la liste"
            SetInput { implicitWidth: 300; text: page.installed.indexOf(Config.terminal) < 0 ? Config.terminal : ""; placeholder: "ex. /usr/bin/st"
                       onCommitted: (t) => { if (t.trim() !== "") Config.set("general.terminal", t.trim()) } }
        }
        SetRow {
            title: "Éditeur de texte"; desc: "ouvre les fichiers texte depuis l'explorateur (dans le terminal)"
            SetInput { implicitWidth: 300; text: String(Config.get("general.editor", "nvim")); placeholder: "nvim"
                       onCommitted: (t) => Config.set("general.editor", t.trim() === "" || t.trim() === "nvim" ? null : t.trim()) }
        }
        SetRow {
            title: "Mise à jour du système"; desc: "lancée par le module Mises à jour (ex. sudo pacman -Syu, sudo apt upgrade, sudo dnf upgrade)"
            SetInput { implicitWidth: 300; text: String(Config.get("general.update_command", "cachy-update")); placeholder: "cachy-update"
                       onCommitted: (t) => Config.set("general.update_command", t.trim() === "" || t.trim() === "cachy-update" ? null : t.trim()) }
        }
    }

    SetCard {
        title: "Écrans"
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "L'écran tactile reçoit le panneau tactile ; la barre, les fenêtres et le fond d'écran animé vont sur les autres. Clique un écran pour le désigner."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        Repeater {
            model: Quickshell.screens
            delegate: Rectangle {
                id: sc
                required property var modelData
                readonly property bool touch: Config.isTouch(modelData)
                Layout.fillWidth: true
                implicitHeight: 58; radius: 12
                color: touch ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.10) : (scMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.05) : "transparent")
                border.width: 1; border.color: touch ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 14
                    // silhouette de l'écran à son ratio
                    Rectangle {
                        readonly property real k: Math.min(44 / sc.modelData.width, 30 / sc.modelData.height)
                        Layout.preferredWidth: sc.modelData.width * k; Layout.preferredHeight: sc.modelData.height * k
                        radius: 3; color: "transparent"; border.width: 2
                        border.color: sc.touch ? Appearance.colors.accent : Appearance.colors.dim
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { Layout.fillWidth: true; text: (sc.modelData.model || sc.modelData.name) + "  ·  " + sc.modelData.name
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg }
                        Text { Layout.fillWidth: true; text: sc.modelData.width + " × " + sc.modelData.height
                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.dim }
                    }
                    Text { text: sc.touch ? "󰦧  tactile" : "principal"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2
                           color: sc.touch ? Appearance.colors.accent : Appearance.colors.dim }
                }
                MouseArea {
                    id: scMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const id = sc.modelData.model || sc.modelData.name
                        Config.set("general.touch_screen", sc.touch ? "" : (id.toUpperCase().indexOf("XENEON") >= 0 ? null : id))
                    }
                }
            }
        }
        Text {
            visible: Config.touchMatch === ""
            text: "Aucun écran désigné : le panneau tactile va sur le plus petit écran (tuile « Touch Panel » pour l'éteindre)."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
    }
}
