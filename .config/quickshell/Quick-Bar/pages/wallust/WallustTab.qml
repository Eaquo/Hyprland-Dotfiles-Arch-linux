import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// WallustTab — édition manuelle de la palette wallust (TouchPanel).
//   · gauche : faux bureau (barre, fenêtre hy3, kitty, popup) recoloré en direct ;
//              toucher un élément sélectionne sa couleur
//   · centre : les 19 couleurs rangées par rôle (fond/texte, accent/états, bordures/stats)
//   · droite : éditeur de la couleur choisie (teinte, saturation, luminosité) + actions
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
        color1:     "Rouge : fermer, erreurs",
        color2:     "Stats réseau (Dashboard, Grid) · bordure 2/5",
        color3:     "Stats disques · lanceur au repos",
        color4:     "Alerte stats barre (>80 %) · onglets · bordure 3/5",
        color5:     "Icône mises à jour · Bluetooth coupé · onglets",
        color6:     "Icône RAM barre · onglets · bordure 4/5",
        color7:     "Texte onglets hy3 inactifs (peu utilisé)",
        color8:     "Texte atténué (partout) · workspaces barre · bordure 5/5",
        color9:     "Onglets · bordure onglet hy3 urgent",
        color10:    "Icônes notifs / Bluetooth actifs · ombre inactive · onglets",
        color11:    "ACCENT : bordures, sélection, élément actif · rofi · boutons Spotify · onglet hy3 actif",
        color12:    "SURVOL / pressé (rofi, Spotify) · stats barre (>50 %) · ombre fenêtre active",
        color13:    "FOCUS / URGENT (rofi, hy3) · workspace actif · icône CPU",
        color14:    "Icône disque barre · onglets · bordure onglet hy3 focus",
        color15:    "Horloge, valeurs, contour barre/dashboard, bordure popups"
    })

    // Palette affichée = palette courante (wal.json via Appearance) + éditions en attente.
    property var edits: ({})
    property string sel: "color11"          // couleur ouverte dans l'éditeur
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

    // Modifie une composante HSL (0 teinte · 1 saturation · 2 luminosité) de la couleur choisie
    function setHsl(ch, v) {
        const c = Qt.color(shown(sel))
        let h = Math.max(0, c.hslHue), sa = c.hslSaturation, l = c.hslLightness
        if (ch === 0) h = Math.min(0.999, v); else if (ch === 1) sa = v; else l = v
        setEdit(sel, Qt.hsla(h, sa, l, 1).toString())
    }
    readonly property var groups: [
        { title: "Fond et texte",     keys: ["background", "foreground", "color8", "color15", "color7", "cursor"] },
        { title: "Accent et états",   keys: ["color11", "color12", "color13", "color10", "color9"] },
        { title: "Bordures et stats", keys: ["color0", "color2", "color4", "color6", "color3", "color14", "color1", "color5"] }
    ]

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
        actionProc.environment = { QB_PALETTE: Appearance.paletteSource, QB_PALETTE_FILE: Appearance.palettePath }
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
        environment: ({ QB_PALETTE: Appearance.paletteSource, QB_PALETTE_FILE: Appearance.palettePath })
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

    // Couleur affichée, animée : tout l'aperçu glisse vers la nouvelle teinte
    component Tint: Rectangle {
        Behavior on color { ColorAnimation { duration: Appearance.dur(350); easing.type: Easing.OutCubic } }
    }

    // Zone de l'aperçu qui sélectionne une couleur au toucher
    component Pick: MouseArea {
        property string key: ""
        anchors.fill: parent
        onClicked: root.sel = key
    }

    RowLayout {
        anchors.fill: parent
        spacing: 22

        // ══ Aperçu : faux bureau recoloré en direct ══════════════════════════
        ClippingRectangle {
            id: preview
            Layout.fillHeight: true
            Layout.preferredWidth: Math.min(parent.width * 0.36, height * 1.75)
            radius: 22
            color: root.shown("background")

            Image {
                anchors.fill: parent
                source: root.wallSrc
                sourceSize.width: 1000
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.25 }

            // Barre
            Tint {
                id: pBar
                x: 16; y: 16; width: parent.width - 32; height: 46; radius: 14
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: ColorUtils.applyAlpha(root.shown("color0"), 0.9) }
                    GradientStop { position: 1; color: ColorUtils.applyAlpha(root.shown("background"), 0.95) }
                }
                border.width: 2; border.color: ColorUtils.applyAlpha(root.shown("color15"), 0.35)
                Pick { key: "color0" }
                Row {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 7
                    Repeater {
                        model: 4
                        delegate: Tint {
                            required property int index
                            width: index === 1 ? 26 : 10; height: 10; radius: 5
                            color: index === 1 ? root.shown("color13") : root.shown("color8")
                        }
                    }
                }
                Row {
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 16
                    Repeater {
                        model: [["󰍛 18%", "color13"], ["󰾆 9.4G", "color6"], ["󰋊 55%", "color14"], ["17:12", "color15"]]
                        delegate: Text {
                            required property var modelData
                            text: modelData[0]
                            font.family: Appearance.font.family; font.pixelSize: 16; font.weight: Font.DemiBold
                            color: root.shown(modelData[1])
                            Behavior on color { ColorAnimation { duration: Appearance.dur(350) } }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.sel = parent.modelData[1] }
                        }
                    }
                }
            }

            // Fenêtre hy3 : bordure en dégradé color0 → color8
            Tint {
                id: pWin
                x: 30; y: pBar.y + pBar.height + 22
                width: parent.width * 0.56; height: parent.height - y - 24
                radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: root.shown("color0") }
                    GradientStop { position: 0.25; color: root.shown("color2") }
                    GradientStop { position: 0.50; color: root.shown("color4") }
                    GradientStop { position: 0.75; color: root.shown("color6") }
                    GradientStop { position: 1.00; color: root.shown("color8") }
                }
                Pick { key: "color4" }
                Tint {
                    anchors.fill: parent; anchors.margins: 4
                    radius: 12
                    color: root.shown("background")
                    Pick { key: "background" }
                    Row {
                        id: pTabs
                        x: 10; y: 10; spacing: 6
                        Repeater {
                            model: [["kitty", true], ["nvim", false], ["btop", false]]
                            delegate: Tint {
                                required property var modelData
                                width: tabTxt.implicitWidth + 26; height: 30; radius: 8
                                color: modelData[1] ? root.shown("color11") : ColorUtils.applyAlpha(root.shown("color0"), 0.8)
                                Text {
                                    id: tabTxt
                                    anchors.centerIn: parent
                                    text: parent.modelData[0]
                                    font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.DemiBold
                                    color: parent.modelData[1] ? root.shown("foreground") : root.shown("color7")
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.sel = parent.modelData[1] ? "color11" : "color7" }
                            }
                        }
                    }
                    Text {
                        x: 16; y: pTabs.y + pTabs.height + 14
                        width: parent.width - 32
                        textFormat: Text.StyledText
                        lineHeight: 1.35
                        font.family: "JetBrains Mono"; font.pixelSize: 14
                        color: root.shown("foreground")
                        readonly property var c: k => String(root.shown(k))
                        text: "<font color='" + c("color13") + "'>florian</font><font color='" + c("color8") + "'>@cachyos</font> "
                            + "<font color='" + c("color11") + "'>❯</font> " + (Appearance.paletteSource === "matugen" ? "matugen image" : "wallust run") + "<br>"
                            + ["color2", "color4", "color6", "color9", "color10", "color12", "color14"].map(k => "<font color='" + c(k) + "'>■</font>").join(" ")
                            + " palette<br><font color='" + c("color1") + "'>✗</font> <font color='" + c("color8") + "'>erreur (color1)</font><br>"
                            + "<font color='" + c("color12") + "'>✓</font> templates régénérés"
                        MouseArea { anchors.fill: parent; onClicked: root.sel = "foreground" }
                    }
                }
            }

            // Popup (Spotify) : contour color15, boutons accent et survol
            Tint {
                x: pWin.x + pWin.width + 18; y: pWin.y + 10
                width: parent.width - x - 22; height: popCol.implicitHeight + 32
                radius: 18
                color: ColorUtils.applyAlpha(root.shown("background"), 0.95)
                border.width: 2; border.color: root.shown("color15")
                Pick { key: "color15" }
                Column {
                    id: popCol
                    x: 16; y: 16; width: parent.width - 32
                    spacing: 6
                    Text { text: "Spotify"; font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold; color: root.shown("color15") }
                    Text { width: parent.width; elide: Text.ElideRight; text: "The Clincher · Chevelle"
                           font.family: Appearance.font.family; font.pixelSize: 13; color: root.shown("color8")
                           MouseArea { anchors.fill: parent; onClicked: root.sel = "color8" } }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: [["▶  Lire", "color11"], ["Survol", "color12"], ["Focus", "color13"]]
                        delegate: Tint {
                            required property var modelData
                            width: parent.width; height: 34; radius: 10
                            color: root.shown(modelData[1])
                            Text { anchors.centerIn: parent; text: parent.modelData[0]
                                   font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold
                                   color: Appearance.textOn(root.shown(parent.modelData[1])) }
                            MouseArea { anchors.fill: parent; onClicked: root.sel = parent.modelData[1] }
                        }
                    }
                }
            }

            // Vague lumineuse qui balaie l'aperçu quand la palette est appliquée
            Rectangle {
                id: sweep
                width: parent.width * 0.5; height: parent.height * 1.6
                y: -parent.height * 0.3; x: -width
                rotation: 18
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00ffffff" }
                    GradientStop { position: 0.5; color: "#55ffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
                NumberAnimation { id: sweepAnim; target: sweep; property: "x"; from: -sweep.width; to: preview.width + sweep.width; duration: Appearance.dur(900); easing.type: Easing.InOutCubic }
            }
        }

        // ══ Couleurs par rôle ════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Repeater {
                model: root.groups
                delegate: Rectangle {
                    id: grp
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 22
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)

                    // Entrée en cascade des groupes
                    opacity: 0
                    property real lift: 24
                    transform: Translate { y: grp.lift }
                    Component.onCompleted: grpIntro.start()
                    SequentialAnimation {
                        id: grpIntro
                        PauseAnimation { duration: grp.index * 90 }
                        ParallelAnimation {
                            NumberAnimation { target: grp; property: "opacity"; to: 1; duration: Appearance.dur(380) }
                            NumberAnimation { target: grp; property: "lift"; to: 0; duration: Appearance.dur(560); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        Text {
                            text: grp.modelData.title
                            font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold
                            font.letterSpacing: 2; font.capitalization: Font.AllUppercase
                            color: Appearance.colors.dim
                            Layout.bottomMargin: 4
                        }

                        Repeater {
                            model: grp.modelData.keys
                            delegate: Rectangle {
                                id: line
                                required property string modelData
                                readonly property bool isSel: root.sel === modelData
                                readonly property bool edited: root.edits[modelData] !== undefined
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.maximumHeight: 66
                                radius: 14
                                color: isSel ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.22)
                                     : lineMa.pressed ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) : "transparent"
                                border.width: isSel ? 2 : 0
                                border.color: Appearance.colors.accent
                                scale: lineMa.pressed ? 0.96 : 1
                                Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
                                Behavior on scale { NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6; anchors.rightMargin: 10
                                    spacing: 12
                                    Tint {
                                        Layout.fillHeight: true
                                        Layout.topMargin: 5; Layout.bottomMargin: 5
                                        Layout.preferredWidth: height
                                        radius: 11
                                        color: root.shown(line.modelData)
                                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                                        // point « modifié » qui apparaît en rebond
                                        Rectangle {
                                            anchors { right: parent.right; top: parent.top; margins: -4 }
                                            width: 14; height: 14; radius: 7
                                            color: Appearance.colors.fg
                                            border.width: 3; border.color: Appearance.colors.bg
                                            scale: line.edited ? 1 : 0
                                            Behavior on scale { NumberAnimation { duration: Appearance.dur(320); easing.type: Easing.OutBack; easing.overshoot: 3 } }
                                        }
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            width: parent.width
                                            text: line.modelData
                                            font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.DemiBold
                                            color: Appearance.colors.fg
                                        }
                                        Text {
                                            width: parent.width
                                            text: root.roles[line.modelData] || ""
                                            font.family: Appearance.font.family; font.pixelSize: 11
                                            color: Appearance.colors.dim
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                MouseArea { id: lineMa; anchors.fill: parent; onClicked: root.sel = line.modelData }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        // ══ Éditeur de la couleur choisie ════════════════════════════════════
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 540
            radius: 22
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Tint {
                        id: bigSw
                        Layout.preferredWidth: 84; Layout.preferredHeight: 84
                        radius: 22
                        color: root.shown(root.sel)
                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                        // petit rebond quand on change de couleur
                        Connections { target: root; function onSelChanged() { popAnim.restart() } }
                        SequentialAnimation {
                            id: popAnim
                            NumberAnimation { target: bigSw; property: "scale"; to: 0.85; duration: Appearance.dur(90) }
                            NumberAnimation { target: bigSw; property: "scale"; to: 1; duration: Appearance.dur(380); easing.type: Easing.OutBack; easing.overshoot: 3 }
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: root.sel; font.family: "JetBrains Mono"; font.pixelSize: 26; font.weight: Font.Bold; color: Appearance.colors.fg }
                        Text { text: String(root.shown(root.sel)).toUpperCase(); font.family: "JetBrains Mono"; font.pixelSize: 18; color: Appearance.colors.dim }
                    }
                    // Saisie précise (hex, roue) : le sélecteur complet
                    Rectangle {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 64
                        radius: 18
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, pickMa.pressed ? 0.14 : 0.06)
                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                        Text { anchors.centerIn: parent; text: "󰏘"; font.family: Appearance.font.family; font.pixelSize: 28; color: Appearance.colors.fg }
                        MouseArea { id: pickMa; anchors.fill: parent
                                    onClicked: picker.open(root.shown(root.sel), root.sel, root.roles[root.sel] || "", root.sel) }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.roles[root.sel] || ""
                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    font.family: Appearance.font.family; font.pixelSize: 14
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.8)
                }

                HslSlider { Layout.fillWidth: true; ch: 0; label: "Teinte" }
                HslSlider { Layout.fillWidth: true; ch: 1; label: "Saturation" }
                HslSlider { Layout.fillWidth: true; ch: 2; label: "Luminosité" }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: root.busy ? "Application…"
                        : root.pendingCount > 0 ? root.pendingCount + " couleur(s) modifiée(s), pas encore appliquées"
                        : root.overrideActive ? "Palette personnalisée active (jusqu'au prochain " + Appearance.paletteSource + ")"
                        : "Palette " + Appearance.paletteSource + " d'origine"
                    font.family: Appearance.font.family; font.pixelSize: 13
                    color: root.pendingCount > 0 ? Appearance.colors.accent : Appearance.colors.dim
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ActionButton {
                        Layout.fillWidth: true
                        label: "Appliquer"; primary: true; count: root.pendingCount
                        enabled: !root.busy && root.pendingCount > 0
                        onTap: { root.apply(); sweepAnim.restart() }
                    }
                    ActionButton {
                        label: "Annuler"
                        enabled: !root.busy && root.pendingCount > 0
                        onTap: root.edits = ({})
                    }
                    ActionButton {
                        label: Appearance.paletteName
                        enabled: !root.busy && root.overrideActive
                        onTap: { root.reset(); sweepAnim.restart() }
                    }
                }
            }
        }
    }

    // ── Curseur HSL : la piste montre la plage de la composante ─────────────
    component HslSlider: Item {
        id: hs
        property int ch: 0              // 0 teinte · 1 saturation · 2 luminosité
        property string label: ""
        readonly property color c: root.shown(root.sel)
        readonly property real h: Math.max(0, c.hslHue)
        readonly property real s: c.hslSaturation
        readonly property real l: c.hslLightness
        readonly property real value: ch === 0 ? h : ch === 1 ? s : l
        // Couleur de la piste à la position p (0..1). Teinte : saturée et lisible même sur un gris.
        function stop(p) {
            if (ch === 0) return Qt.hsla(Math.min(p, 0.999), Math.max(s, 0.6), Math.min(0.7, Math.max(0.35, l)), 1)
            if (ch === 1) return Qt.hsla(h, p, l, 1)
            return Qt.hsla(h, s, p, 1)
        }
        implicitHeight: 74

        Text {
            anchors { left: parent.left; top: parent.top }
            text: hs.label
            font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
            font.letterSpacing: 1.5; font.capitalization: Font.AllUppercase
            color: Appearance.colors.dim
        }
        Text {
            anchors { right: parent.right; top: parent.top }
            text: hs.ch === 0 ? Math.round(hs.h * 360) + "°" : Math.round(hs.value * 100) + " %"
            font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.DemiBold
            color: Appearance.colors.fg
        }
        Rectangle {
            id: hTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
            height: 38; radius: 19
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0/6; color: hs.stop(0/6) }
                GradientStop { position: 1/6; color: hs.stop(1/6) }
                GradientStop { position: 2/6; color: hs.stop(2/6) }
                GradientStop { position: 3/6; color: hs.stop(3/6) }
                GradientStop { position: 4/6; color: hs.stop(4/6) }
                GradientStop { position: 5/6; color: hs.stop(5/6) }
                GradientStop { position: 6/6; color: hs.stop(6/6) }
            }
            Rectangle {
                width: hsMa.pressed ? 44 : 36; height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: hTrack.width * hs.value - width / 2
                color: hs.c
                border.width: 4; border.color: "#ffffff"
                Behavior on width { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Behavior on x { enabled: !hsMa.pressed; NumberAnimation { duration: Appearance.dur(300); easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: hsMa
                anchors.fill: parent; anchors.margins: -12
                preventStealing: true
                function upd(mx) { root.setHsl(hs.ch, Math.max(0, Math.min(1, (mx - 12) / hTrack.width))) }
                onPressed: (e) => upd(e.x)
                onPositionChanged: (e) => { if (pressed) upd(e.x) }
            }
        }
    }

    component ActionButton: Rectangle {
        id: btn
        property string label
        property bool primary: false
        property int count: 0
        signal tap()
        implicitWidth: btnRow.implicitWidth + 36
        implicitHeight: 60
        radius: 18
        opacity: enabled ? 1 : 0.4
        color: primary ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
        scale: btnMa.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
        Row {
            id: btnRow
            anchors.centerIn: parent; spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label; font.family: Appearance.font.family; font.pixelSize: 17; font.weight: Font.Bold
                font.letterSpacing: 1; font.capitalization: Font.AllUppercase
                color: btn.primary ? Appearance.textOn(Appearance.colors.accent) : Appearance.colors.fg
            }
            // compteur qui rebondit à chaque changement
            Rectangle {
                id: cnt
                visible: btn.primary && btn.count > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(28, cntTxt.implicitWidth + 14); height: 28; radius: 14
                color: Appearance.textOn(Appearance.colors.accent)
                Text { id: cntTxt; anchors.centerIn: parent; text: btn.count
                       font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold; color: Appearance.colors.accent }
                Connections { target: btn; function onCountChanged() { bump.restart() } }
                SequentialAnimation {
                    id: bump
                    NumberAnimation { target: cnt; property: "scale"; to: 1.45; duration: Appearance.dur(110) }
                    NumberAnimation { target: cnt; property: "scale"; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutBack; easing.overshoot: 3 }
                }
            }
        }
        MouseArea { id: btnMa; anchors.fill: parent; enabled: btn.enabled; onClicked: btn.tap() }
    }

    // Sélecteur de couleur tactile complet (components/ColorPicker.qml)
    ColorPicker { id: picker; onPicked: (hex, tag) => root.setEdit(tag, hex) }
}
