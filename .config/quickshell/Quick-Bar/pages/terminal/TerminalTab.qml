import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QMLTermWidget
import qs.components
import qs.core
import qs.core.functions

// TerminalTab — onglet Terminal du TouchPanel : un vrai terminal (qmltermwidget, le moteur de Konsole) avec
// fish, sans fastfetch (QB_CLEAN=1, prévu par ~/.config/fish/config.fish), la police de kitty et les couleurs
// de la palette. Jusqu'à 3 sessions côte à côte (split vertical, + / ×) qui survivent aux changements d'onglet (keep: true dans TouchTabs).
// Couleurs : un .colorscheme écrit dans <cache>/quickbar/qml/QMLTermWidget/color-schemes, dossier ajouté à
// QML_IMPORT_PATH par scripts/launch.sh ; deux noms alternés (A/B) parce qu'un schéma chargé reste en cache.
// Rendu : une carte par volet qui se déroule depuis son centre (sans rebond), contour en dégradé animé sur la
// carte active, sans halo. Tables de clavier : liées par launch.sh.
// [terminal] dans config.toml : font, font_size, opacity (carte des touches), radius.
Item {
    id: root
    readonly property string schemeDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
                                        + "/quickbar/qml/QMLTermWidget/color-schemes"
    property int fontSize: Number(Config.get("terminal.font_size", 19))

    // ── Sessions : jusqu'à 3, chacune un terminal indépendant qui reste ouvert en arrière-plan ──
    readonly property int maxSessions: 3
    ListModel { id: sessions }              // { uid } ; retirer une ligne ne détruit que sa session
    property int current: 0
    property int nextUid: 1
    property var term: null                 // terminal affiché (cible de la barre d'outils)
    property var sess: null
    function addSession() {
        if (sessions.count >= maxSessions) return
        sessions.append({ uid: nextUid++ }); current = sessions.count - 1
    }
    // fermeture animée : le volet se replie (closing), puis sa ligne est retirée (removeSession)
    property int closingCount: 0
    readonly property int openCount: sessions.count - closingCount
    function closeSession(i) {
        const it = termRepeater.itemAt(i)
        if (!it || it.closing || openCount <= 1) return
        it.closing = true; closingCount++
        if (i === current) current = i > 0 ? i - 1 : i + 1
    }
    function removeSession(i) {
        const cur = current
        sessions.remove(i); closingCount--
        current = Math.max(0, Math.min(sessions.count - 1, cur > i ? cur - 1 : cur))
        Qt.callLater(() => { const it = termRepeater.itemAt(current); if (it) it.show() })   // focus = volet surligné
    }
    Component.onCompleted: { addSession(); writeScheme() }

    // ── Schéma de couleurs aux couleurs de la palette (appliqué à toutes les sessions) ──
    property string scheme: ""
    function rgb(c) { return Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) }
    function schemeText(name) {
        const C = Appearance.colors, out = []
        const sec = (n, c) => out.push("[" + n + "]", "Color=" + rgb(c), "")
        sec("Background", C.bg); sec("BackgroundIntense", C.bg); sec("BackgroundFaint", C.bg)
        sec("Foreground", C.fg); sec("ForegroundIntense", C.fg); sec("ForegroundFaint", C.dim)
        for (let i = 0; i < 8; i++) {
            sec("Color" + i, C["color" + i]); sec("Color" + i + "Intense", C["color" + (i + 8)])
            sec("Color" + i + "Faint", Qt.darker(C["color" + i], 1.6))
        }
        out.push("[General]", "Description=" + name, "Opacity=1", "")
        return out.join("\n")
    }
    property string pending: ""
    Process {
        id: schemeProc
        onExited: (code) => { if (code === 0) root.scheme = root.pending }
    }
    function writeScheme() {
        pending = scheme === "QuickbarA" ? "QuickbarB" : "QuickbarA"
        schemeProc.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$1/$3.colorscheme"', "_",
                              schemeDir, schemeText(pending), pending]
        schemeProc.running = true
    }
    // la palette change (wallust, matugen, accent) → nouveau schéma
    readonly property string palKey: [Appearance.colors.bg, Appearance.colors.fg, Appearance.colors.color0, Appearance.colors.color1,
        Appearance.colors.color2, Appearance.colors.color3, Appearance.colors.color4, Appearance.colors.color5, Appearance.colors.color6,
        Appearance.colors.color7, Appearance.colors.color8, Appearance.colors.color9, Appearance.colors.color10, Appearance.colors.color11,
        Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14, Appearance.colors.color15].join()
    onPalKeyChanged: schemeKick.restart()
    Timer { id: schemeKick; interval: 300; onTriggered: root.writeScheme() }

    // touches que le clavier virtuel n'a pas, ou peu pratiques au doigt (session affichée)
    function key(k, mods, text) { if (!term) return; term.simulateKeyPress(k, mods || 0, true, 0, text || ""); term.forceActiveFocus() }
    function send(t) { if (!sess) return; sess.sendText(t); term.forceActiveFocus() }
    onVisibleChanged: if (visible && term) term.forceActiveFocus()

    // ── Volets : une carte par terminal (split vertical, 3 max), séparées ──
    // Nouveau volet : la carte se déroule depuis son centre pendant que les autres se resserrent (OutCubic, sans
    // rebond) ; fermeture : elle se referme puis disparaît. Carte active : contour en dégradé animé.
    readonly property int radius: Number(Config.get("terminal.radius", 16))
    Row {
        id: panes
        clip: true                               // rien ne déborde sur la barre de touches pendant les animations
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: toolCard.left; margins: 14; rightMargin: 12 }
        spacing: 12
        Repeater {
            id: termRepeater
            model: sessions
            delegate: Item {
                id: slot
                required property int index
                property bool ended: false
                property bool closing: false
                property bool born: false            // passe à vrai juste après la création → ouverture animée
                readonly property bool cur: index === root.current && !closing
                readonly property real share: (panes.width - panes.spacing * Math.max(0, root.openCount - 1)) / Math.max(1, root.openCount)
                width: closing || !born ? 0 : share
                height: panes.height
                opacity: closing || !born ? 0 : 1
                Behavior on width { NumberAnimation { duration: Appearance.dur(380); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                Timer { running: slot.closing; interval: Appearance.dur(400); onTriggered: root.removeSession(slot.index) }
                function show() { root.term = t; root.sess = s; t.forceActiveFocus() }
                onCurChanged: if (cur) show()
                Component.onCompleted: { Qt.callLater(() => slot.born = true); if (cur) show() }

                // la carte s'ouvre / se referme depuis son centre ; le contenu garde sa largeur finale (pas de
                // redimensionnement du terminal pendant l'animation), la carte ne fait que le dévoiler
                ClippingRectangle {
                    id: card
                    anchors.fill: parent
                    radius: Math.min(root.radius, width / 2)
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
                    border.width: 1
                    border.color: slot.cur ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.6) : ColorUtils.applyAlpha(Appearance.colors.color15, 0.18)
                    Behavior on border.color { ColorAnimation { duration: Appearance.dur(200) } }
                  Item {
                    x: (card.width - width) / 2
                    width: slot.share; height: card.height

                        Item {
                            id: head
                            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 10; topMargin: 6 }
                            height: 30
                            visible: root.openCount > 1 || sessions.count < root.maxSessions
                            MouseArea { anchors.fill: parent; onClicked: root.current = slot.index }
                            Row {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Rectangle {                  // diviser : nouvelle session à droite
                                    visible: slot.index === sessions.count - 1 && sessions.count < root.maxSessions && !slot.closing
                                    width: 30; height: 30; radius: 15
                                    color: ColorUtils.applyAlpha(Appearance.colors.fg, addMa.pressed ? 0.15 : 0.05)
                                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.3)
                                    Text { anchors.centerIn: parent; text: "󰐕"; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.accent }
                                    MouseArea { id: addMa; anchors.fill: parent; anchors.margins: -6; onClicked: root.addSession() }
                                }
                                Rectangle {                  // fermer ce volet
                                    visible: root.openCount > 1
                                    width: 30; height: 30; radius: 15
                                    color: ColorUtils.applyAlpha(Appearance.colors.color13, xMa.pressed ? 0.3 : 0.0)
                                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 16
                                           color: xMa.pressed ? Appearance.colors.color13 : Appearance.colors.dim }
                                    MouseArea { id: xMa; anchors.fill: parent; anchors.margins: -6; onClicked: root.closeSession(slot.index) }
                                }
                            }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; radius: 1
                                        color: Appearance.colors.accent; opacity: slot.cur && root.openCount > 1 ? 0.8 : 0
                                        Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } } }
                        }
    
                        QMLTermWidget {
                            id: t
                            anchors { left: parent.left; right: parent.right; top: head.visible ? head.bottom : parent.top; bottom: parent.bottom
                                      margins: 12; topMargin: head.visible ? 8 : 12 }
                            colorScheme: root.scheme
                            font.family: String(Config.get("terminal.font", "Fira Code"))
                            font.pixelSize: root.fontSize
                            font.weight: Font.DemiBold
                            antialiasText: true
                            blinkingCursor: true
                            fullCursorHeight: true
                            onActiveFocusChanged: if (activeFocus) root.current = slot.index
                            session: QMLTermSession {
                                id: s
                                initialWorkingDirectory: Quickshell.env("HOME")
                                // env : le module ne sait pas passer de variables ; QB_CLEAN coupe fastfetch dans config.fish
                                shellProgram: "/usr/bin/env"
                                shellProgramArgs: ["QB_CLEAN=1", "TERM=xterm-256color", "COLORTERM=truecolor", "fish"]
                                // exit : le volet se ferme, sauf le dernier (toucher pour relancer)
                                onFinished: { if (root.openCount > 1) root.closeSession(slot.index); else slot.ended = true }
                            }
                            Component.onCompleted: s.startShellProgram()
    
                            // défilement au doigt (la molette et la sélection à la souris restent au terminal)
                            DragHandler {
                                target: null
                                acceptedDevices: PointerDevice.TouchScreen
                                property real last: 0
                                onActiveChanged: last = 0
                                onTranslationChanged: {
                                    const dy = translation.y - last; last = translation.y
                                    t.simulateWheel(t.width / 2, t.height / 2, 0, 0, Qt.point(0, dy * 4))
                                }
                            }
                            TapHandler { onTapped: { root.current = slot.index; t.forceActiveFocus() } }
    
                            // barre de défilement discrète (visible quand on remonte dans l'historique)
                            Rectangle {
                                readonly property int total: t.lines + t.scrollbarMaximum - t.scrollbarMinimum
                                visible: t.scrollbarMaximum > t.scrollbarMinimum && t.scrollbarCurrentValue < t.scrollbarMaximum
                                anchors.right: parent.right
                                width: 5; radius: 3
                                height: Math.max(30, t.height * t.lines / Math.max(1, total))
                                y: (t.height - height) * (t.scrollbarCurrentValue - t.scrollbarMinimum) / Math.max(1, t.scrollbarMaximum - t.scrollbarMinimum)
                                color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.7)
                            }
                        }
    
                        // dernière session terminée (exit) → toucher pour relancer
                        Rectangle {
                            anchors.fill: parent
                            visible: slot.ended
                            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.85)
                            Column {
                                anchors.centerIn: parent; spacing: 8
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰆍"; font.family: Appearance.font.family; font.pixelSize: 40; color: Appearance.colors.accent }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Session terminée · toucher pour relancer"
                                       font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.fg }
                            }
                            MouseArea { anchors.fill: parent; onClicked: { slot.ended = false; s.startShellProgram(); t.forceActiveFocus() } }
                        }
                  }
                }
                GradientBorder {
                    anchors.fill: parent; radius: card.radius; borderWidth: 2
                    visible: slot.cur && slot.born && !slot.closing && Math.abs(slot.width - slot.share) < 1
                    opacity: t.activeFocus ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                }
            }
        }
    }

    // ── Barre d'outils (droite), dans une carte assortie ──
    Rectangle {
        id: toolCard
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: 14 }
        width: tools.width + 20; radius: root.radius
        color: ColorUtils.applyAlpha(Appearance.colors.bg, Number(Config.get("terminal.opacity", 0.62)))
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.25)
    }
    Flow {
        id: tools
        anchors { horizontalCenter: toolCard.horizontalCenter; top: toolCard.top; bottom: toolCard.bottom; topMargin: 10; bottomMargin: 10 }
        width: 2 * 62 + 8
        flow: Flow.TopToBottom
        spacing: 8
        Repeater {
            model: [
                { g: "Esc", t: "Échap",   f: () => root.key(Qt.Key_Escape) },
                { g: "⇥",   t: "Tab",     f: () => root.key(Qt.Key_Tab, 0, "\t") },
                { g: "󰌑",   t: "Entrée",  f: () => root.key(Qt.Key_Return, 0, "\r") },
                { g: "^C",  t: "Ctrl+C",  f: () => root.send("\x03") },
                { g: "^D",  t: "Ctrl+D",  f: () => root.send("\x04") },
                { g: "󰁝",   t: "Haut",    f: () => root.key(Qt.Key_Up) },
                { g: "󰁅",   t: "Bas",     f: () => root.key(Qt.Key_Down) },
                { g: "󰁍",   t: "Gauche",  f: () => root.key(Qt.Key_Left) },
                { g: "󰁔",   t: "Droite",  f: () => root.key(Qt.Key_Right) },
                { g: "󰆏",   t: "Copier",  f: () => root.term && root.term.copyClipboard() },
                { g: "󰆒",   t: "Coller",  f: () => { if (root.term) { root.term.pasteClipboard(); root.term.forceActiveFocus() } } },
                { g: "󰃢",   t: "Effacer", f: () => root.send("\x0c") },
                { g: "󰌌",   t: "Clavier", f: () => Quickshell.execDetached(["sh", "-c", "pkill -x wvkbd-mobintl || exec wvkbd-mobintl -L 280 --alpha 235 --bg $1 --fg $2 --fg-sp $3 --press $4 --text $5 --text-sp $5",
                                                   "_", Appearance.colors.bg.toString().slice(1), Appearance.colors.color0.toString().slice(1),
                                                   Appearance.colors.color8.toString().slice(1), Appearance.colors.accent.toString().slice(1),
                                                   Appearance.colors.fg.toString().slice(1)]) },
                { g: "A−",  t: "Plus petit", f: () => Config.set("terminal.font_size", Math.max(9, root.fontSize - 1)) },
                { g: "A+",  t: "Plus grand", f: () => Config.set("terminal.font_size", Math.min(32, root.fontSize + 1)) },
                { g: "󰄛",   t: "Ouvrir dans kitty", f: () => Quickshell.execDetached(["kitty", "--directory", (root.sess && root.sess.currentDir) || Quickshell.env("HOME")]) }
            ]
            delegate: Rectangle {
                id: btn
                required property var modelData
                width: 62; height: 50; radius: 12
                color: ma.pressed ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.35) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, ma.pressed ? 0.8 : 0.18)
                Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                scale: ma.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Appearance.dur(120) } }
                Text { anchors.centerIn: parent; text: btn.modelData.g; font.family: Appearance.font.family; font.pixelSize: 18
                       font.weight: Font.DemiBold; color: ma.pressed ? Appearance.colors.fg : Appearance.colors.accent }
                MouseArea { id: ma; anchors.fill: parent; onClicked: btn.modelData.f() }
            }
        }
    }
}
