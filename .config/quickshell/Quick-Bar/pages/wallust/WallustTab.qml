import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// WallustTab — édition manuelle de la palette wallust (TouchPanel).
//   · gauche : les 19 couleurs (special + color0..15), tap → sélecteur tactile
//   · droite : wallpaper courant encadré + Actualiser / Reset
// Actualiser = `wallust cs` sur la palette modifiée → tous les templates
// (Hyprland, kitty, rofi, wal.json…) sont régénérés. La palette d'origine est
// sauvée et Reset la réapplique. Un nouveau `wallust run` écrase la surcharge.
// Logique fichiers : scripts/wallust/wallust_override.sh.
Item {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/wallust/wallust_override.sh"
    readonly property var keys: ["background", "foreground", "cursor",
        "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7",
        "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"]
    readonly property var specialKeys: ["background", "foreground", "cursor"]
    // Rôle de chaque couleur, vérifié dans le code : Quick-Bar d'abord, puis
    // Hyprland (configs lua/Settings.lua + Decorations.lua, onglets hy3).
    // « bordure N/5 » = dégradé de la bordure de fenêtre active ; « onglets » =
    // pastilles TouchPanel/Dashboard. color1-6 et 9-14 alimentent aussi les
    // bordures animées (Appearance.legiblePalette). À tenir à jour si ça change.
    readonly property var roles: ({
        background: "Fond de toute la Quick-Bar · kitty · bordure fenêtre inactive",
        foreground: "Texte principal Quick-Bar · kitty · texte onglets hy3",
        cursor:     "Curseur kitty (pas utilisé par Quick-Bar)",
        color0:     "Dégradé fond des modules barre · jour du calendrier · bordure 1/5",
        color1:     "Rouge : fermer, erreurs · onglet hy3 urgent",
        color2:     "Stats réseau (Dashboard, Grid) · bordure 2/5",
        color3:     "Stats disques · lanceur au repos",
        color4:     "Alerte stats barre (>80 %) · onglets · bordure 3/5",
        color5:     "Icône mises à jour · Bluetooth coupé · onglets",
        color6:     "Icône RAM barre · onglets · bordure 4/5",
        color7:     "Texte onglets hy3 inactifs (peu utilisé)",
        color8:     "Texte atténué (partout) · workspaces barre · bordure 5/5",
        color9:     "Onglets · bordure onglet hy3 urgent",
        color10:    "Icônes notifs / Bluetooth actifs · ombre inactive · onglets",
        color11:    "ACCENT : bordures, sélection, élément actif · onglets",
        color12:    "Stats barre (>50 %) · ombre fenêtre active · onglets",
        color13:    "Workspace actif · icône CPU · onglet hy3 actif · onglets",
        color14:    "Icône disque barre · onglets · bordure onglet hy3 focus",
        color15:    "Horloge, valeurs, contour barre/dashboard, bordure popups"
    })

    // Palette affichée = palette courante (wal.json via Appearance) + éditions en attente.
    property var edits: ({})
    property bool overrideActive: false
    property bool busy: false

    function current(k) {
        return (specialKeys.indexOf(k) !== -1 ? Appearance._special[k] : Appearance._palette[k]) || "#000000"
    }
    function shown(k) { return edits[k] !== undefined ? edits[k] : current(k) }
    readonly property int pendingCount: Object.keys(edits).length

    function setEdit(k, hex) {
        const e = Object.assign({}, edits)
        if (hex.toLowerCase() === String(current(k)).toLowerCase()) delete e[k]
        else e[k] = hex
        edits = e
    }

    function apply() {
        const special = {}, colors = {}
        for (const k of keys) {
            if (specialKeys.indexOf(k) !== -1) special[k] = shown(k)
            else colors[k] = shown(k)
        }
        const json = JSON.stringify({ wallpaper: WallpaperState.currentWall, alpha: "100", special: special, colors: colors })
        run(["bash", script, "apply", json])
    }
    function reset() { run(["bash", script, "reset"]) }

    function run(cmd) {
        busy = true
        actionProc.command = cmd
        actionProc.running = true
        GameBreak.extend()
    }
    Process {
        id: actionProc
        onExited: { root.busy = false; root.edits = ({}); statusProc.running = true }
    }
    Process {
        id: statusProc
        command: ["bash", root.script, "status"]
        stdout: StdioCollector { onStreamFinished: root.overrideActive = text.trim() === "override" }
    }
    Component.onCompleted: statusProc.running = true
    // wal.json régénéré (par nous ou par un `wallust run`) → rafraîchir le statut.
    readonly property string paletteSig: JSON.stringify(Appearance._palette)
    onPaletteSigChanged: if (!busy) statusProc.running = true

    // Mode vidéo : currentWall est un .mp4 → vignette statique (cf. TouchPanel).
    readonly property string wallSrc: WallpaperState.videoMode
        ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
        : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // ══ Couleurs : 2 colonnes sur toute la hauteur ══
        GridLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.5
            columns: 2
            flow: GridLayout.TopToBottom
            rows: Math.ceil(root.keys.length / 2)
            rowSpacing: 8; columnSpacing: 16

            Repeater {
                model: root.keys
                delegate: Rectangle {
                    id: cell
                    required property string modelData
                    readonly property bool edited: root.edits[modelData] !== undefined
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.width: edited ? 2 : 1
                    border.color: edited ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 14
                        spacing: 14
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.topMargin: 5; Layout.bottomMargin: 5
                            Layout.preferredWidth: 90
                            radius: 9
                            color: root.shown(cell.modelData)
                            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                width: parent.width
                                text: cell.modelData
                                font.family: Appearance.font.family; font.pixelSize: 17; font.weight: Font.Medium
                                color: Appearance.colors.fg
                            }
                            Text {
                                width: parent.width
                                text: root.roles[cell.modelData] || ""
                                font.family: Appearance.font.family; font.pixelSize: 12
                                color: Appearance.colors.dim
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: String(root.shown(cell.modelData)).toUpperCase()
                            font.family: Appearance.font.family; font.pixelSize: 16
                            color: cell.edited ? Appearance.colors.accent : Appearance.colors.dim
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: picker.open(root.shown(cell.modelData), cell.modelData,
                                               root.roles[cell.modelData] || "", cell.modelData)
                    }
                }
            }
        }

        // ══ Wallpaper + actions ══
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            ClippingRectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: Appearance.colors.bg
                border.width: 3
                border.color: Appearance.colors.accent
                Image {
                    anchors.fill: parent
                    source: root.wallSrc
                    sourceSize.width: 1400
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Aperçu de la palette affichée (bande en bas du wallpaper).
                Row {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 26
                    Repeater {
                        model: 16
                        Rectangle {
                            required property int index
                            width: parent.width / 16; height: parent.height
                            color: root.shown("color" + index)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    Layout.fillWidth: true
                    text: root.busy ? "Application…"
                        : root.pendingCount > 0 ? root.pendingCount + " couleur(s) modifiée(s) — non appliquées"
                        : root.overrideActive ? "Palette personnalisée active (jusqu'au prochain wallust)"
                        : "Palette wallust d'origine"
                    font.family: Appearance.font.family; font.pixelSize: 16
                    color: root.pendingCount > 0 ? Appearance.colors.accent : Appearance.colors.dim
                    elide: Text.ElideRight
                }
                ActionButton {
                    icon: "󰑓"; label: "Reset"
                    enabled: !root.busy && (root.overrideActive || root.pendingCount > 0)
                    onTap: { if (root.overrideActive) root.reset(); else root.edits = ({}) }
                }
                ActionButton {
                    icon: "󰸞"; label: "Actualiser"; primary: true
                    enabled: !root.busy && root.pendingCount > 0
                    onTap: root.apply()
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: btn
        property string icon
        property string label
        property bool primary: false
        signal tap()
        implicitWidth: btnRow.implicitWidth + 40
        implicitHeight: 64
        radius: 18
        opacity: enabled ? 1 : 0.4
        color: primary ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
        Row {
            id: btnRow
            anchors.centerIn: parent; spacing: 10
            Text {
                text: btn.icon; font.family: Appearance.font.family; font.pixelSize: 24
                color: btn.primary ? Appearance.colors.bg : Appearance.colors.fg
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label; font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                color: btn.primary ? Appearance.colors.bg : Appearance.colors.fg
            }
        }
        MouseArea { anchors.fill: parent; enabled: btn.enabled; onClicked: btn.tap() }
    }

    // Sélecteur de couleur tactile partagé (Components/ColorPicker.qml)
    ColorPicker { id: picker; onPicked: (hex, tag) => root.setEdit(tag, hex) }
}
