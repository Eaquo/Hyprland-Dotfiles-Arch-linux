import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// AppDock — onglet Apps du TouchPanel, façon « dock vivant » :
//  • En cours : une carte par fenêtre ouverte (aperçu en direct, appli, titre, espace) ; toucher = y aller,
//    × = fermer. Suivi natif (ToplevelManager + HyprlandToplevel), aucun sondage.
//  • Bouton Apps : toutes les applis de core/AppDeck.qml (Réglages › Apps) dans AppsLauncher.qml, en 5 styles
//    ([apps] launcher_style). Toucher = aller à sa fenêtre si elle est ouverte, sinon lancer ; appui long = nouvelle.
Item {
    id: root
    readonly property bool shown: visible && width > 0

    // fenêtres des espaces normaux (pas les spéciaux : réduites, scratchpads)
    // HyprlandToplevel : .workspace, .address, .wayland (fenêtre Wayland : appId, activated, close, aperçu)
    // + espaces spéciaux (special:magic = SUPER+U, scratchpads pyprland special:scratch_*), en dernier ; pas les
    // fenêtres réduites (special:minimized, module Minimized de la barre)
    function isSpecial(t) { return t.workspace && t.workspace.id < 0 }
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.wayland && t.workspace
                                       && (t.workspace.id > 0 || (t.workspace.name || "").startsWith("special:") && t.workspace.name !== "special:minimized"))
                                   .sort((a, b) => (isSpecial(a) - isSpecial(b)) || (a.workspace.id - b.workspace.id))
    // toucher une fenêtre d'espace spécial : affiche / cache son scratchpad
    function toggleSpecial(t) {
        const n = t.workspace.name.slice(8)                         // après « special: »
        if (n.startsWith("scratch_")) Quickshell.execDetached(["pypr", "toggle", n.slice(8)])
        else { hypr.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.workspace.toggle_special(\"" + n + "\"))"]; hypr.running = false; hypr.running = true }
        GameBreak.extend()
    }

    function icon(appId) {
        return Quickshell.iconPath(DesktopEntries.heuristicLookup(appId)?.icon ?? appId, "application-x-executable")
    }
    function appName(t) { return DesktopEntries.heuristicLookup(t.wayland?.appId)?.name || t.wayland?.appId || "Fenêtre" }

    Process { id: hypr }
    function focus(t) {
        hypr.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:0x" + t.address + "' }))"]
        hypr.running = false; hypr.running = true
        GameBreak.extend()
    }
    // fenêtre ouverte d'un favori : l'identifiant d'appli contient le nom de la commande (kitty, zen, spotify…)
    function windowFor(exec) {
        const bin = (exec || "").trim().split(/\s+/).filter(w => !w.startsWith("-") && w.indexOf("=") < 0)
        const names = bin.map(w => w.split("/").pop().toLowerCase())
        if (names[0] === "kitty" && names.length > 1) return null           // « kitty -e nvim » : pas « kitty »
        return windows.find(t => names.some(n => n.length > 2 && (t.wayland?.appId || "").toLowerCase().indexOf(n) >= 0)) || null
    }

    ColumnLayout {
        anchors { fill: parent; margins: 14; rightMargin: 14 + 132 + 14 }
        scale: launcher.style === "spotlight" ? 1 - 0.07 * launcher.p : 1
        opacity: launcher.style === "spotlight" ? 1 - 0.6 * launcher.p : 1
        spacing: 14

        // ── En cours ──
        RowLayout {
            Layout.fillWidth: true
            Text { text: "EN COURS"; font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                   font.letterSpacing: 2; color: Appearance.colors.dim }
            Text { text: root.windows.length; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.accent }
            Item { Layout.fillWidth: true }
        }
        ListView {
            id: running
            Layout.fillWidth: true; Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 14; clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.windows
            readonly property real cardW: Math.min(420, Math.max(300, (width - 3 * spacing) / 4))

            add: Transition { NumberAnimation { properties: "opacity,scale"; from: 0; duration: Appearance.dur(260); easing.type: Easing.OutCubic } }
            remove: Transition { NumberAnimation { properties: "opacity,scale"; to: 0; duration: Appearance.dur(220) } }
            displaced: Transition { NumberAnimation { properties: "x"; duration: Appearance.dur(260); easing.type: Easing.OutCubic } }

            delegate: Item {
                id: win
                required property var modelData
                required property int index
                readonly property bool on: !!modelData.wayland?.activated
                width: running.cardW; height: running.height
                scale: tap.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Appearance.dur(120) } }

                ClippingRectangle {
                    anchors.fill: parent; radius: 18
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
                    border.width: 1
                    border.color: win.on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.7) : ColorUtils.applyAlpha(Appearance.colors.color15, 0.16)

                    // aperçu en direct (seulement quand l'onglet est affiché)
                    ScreencopyView {
                        id: shot
                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: info.top; margins: 8 }
                        captureSource: root.shown ? win.modelData.wayland : null
                        live: root.shown && win.index < 6
                        layer.enabled: true
                    }
                    Image {
                        anchors.centerIn: shot; visible: !shot.hasContent
                        width: 72; height: 72; sourceSize: Qt.size(144, 144)
                        source: root.icon(win.modelData.wayland?.appId)
                    }

                    // bas de carte : icône, appli, titre, espace
                    Item {
                        id: info
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 64
                        Image { id: ico; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                width: 34; height: 34; sourceSize: Qt.size(68, 68); source: root.icon(win.modelData.wayland?.appId) }
                        Column {
                            anchors { left: ico.right; leftMargin: 12; right: ws.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text { width: parent.width; elide: Text.ElideRight; text: root.appName(win.modelData)
                                   font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                                   color: win.on ? Appearance.colors.accent : Appearance.colors.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: win.modelData.title || win.modelData.wayland?.title || ""
                                   font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                        }
                        Rectangle {
                            id: ws
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 34; height: 34; radius: 17
                            color: ColorUtils.applyAlpha(Appearance.colors.accent, win.on ? 0.3 : 0.1)
                            Text { anchors.centerIn: parent; text: root.isSpecial(win.modelData) ? "S" : (win.modelData.workspace?.id ?? "?")
                                   font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold; color: Appearance.colors.accent }
                        }
                    }
                }
                TapHandler { id: tap; onTapped: root.isSpecial(win.modelData) ? root.toggleSpecial(win.modelData) : root.focus(win.modelData) }

                // fermer
                Rectangle {
                    anchors { top: parent.top; right: parent.right; margins: 12 }
                    width: 38; height: 38; radius: 19
                    color: xMa.pressed ? ColorUtils.applyAlpha(Appearance.colors.color13, 0.5) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.8)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.color15, 0.2)
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 18
                           color: xMa.pressed ? Appearance.colors.fg : Appearance.colors.dim }
                    MouseArea { id: xMa; anchors.fill: parent; anchors.margins: -6
                                onClicked: { win.modelData.wayland?.close(); GameBreak.extend() } }
                }
            }

            Text {
                anchors.centerIn: parent; visible: running.count === 0
                text: "Aucune fenêtre ouverte"; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.dim
            }
        }
    }

    // ── Bouton Apps : ouvre toutes les applis enregistrées (style au choix, Réglages › Apps) ──
    Rectangle {
        id: appsBtn
        anchors { right: parent.right; bottom: parent.bottom; margins: 14 }
        width: 132; height: 132; radius: 34
        z: 30
        color: launcher.open ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.3) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, launcher.open ? 0.9 : 0.45)
        scale: btnMa.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: Appearance.dur(120) } }
        Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
        Text { anchors.centerIn: parent; text: launcher.open ? "󰅖" : "󰀻"; font.family: Appearance.font.family
               font.pixelSize: 54; color: Appearance.colors.accent
               rotation: launcher.open ? 90 : 0; Behavior on rotation { NumberAnimation { duration: Appearance.dur(300); easing.type: Easing.OutCubic } } }
        MouseArea { id: btnMa; anchors.fill: parent; onClicked: { launcher.open = !launcher.open; GameBreak.extend() } }
    }

    AppsLauncher {
        id: launcher
        anchors.fill: parent
        z: 20
        origin: Qt.point(appsBtn.x + appsBtn.width / 2, appsBtn.y + appsBtn.height / 2)
        onPick: (a) => { const w = root.windowFor(a.exec); if (w) root.focus(w); else { AppDeck.launch(a.exec); GameBreak.extend() }; close() }
        onPickNew: (a) => { AppDeck.launch(a.exec); GameBreak.extend(); close() }
    }
    onShownChanged: if (!shown) launcher.open = false
}
