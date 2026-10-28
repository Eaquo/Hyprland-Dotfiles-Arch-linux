import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.components
import qs.services
import qs.core
import qs.core.functions

// TouchPanel — panneau plein écran sur le tactile Corsair Xeneon Edge.
//
// Même principe que le Dashboard : une barre d'onglets (ici agrandie pour le
// tactile) qui réutilise directement les pages du Dashboard —
//   DashHome · DashStats · KanbanBoard · FileBrowser · WallpaperTab · EqDash.
//
// Layer Overlay opaque (fond = wallpaper courant flouté) → les applications sous
// le panneau sont masquées. Activé par ShellState.touchPanelOn (tuile Quick
// Settings). Écran cible = Xeneon Edge (par modèle), sinon le plus petit écran.
Scope {
    id: root

    property string page: "home"

    // Écran cible = Xeneon Edge (par modèle), sinon le plus petit écran.
    readonly property var targetScreen: {
        var all = Quickshell.screens
        for (var i = 0; i < all.length; i++)
            if (Config.isTouch(all[i])) return all[i]
        var s = null, best = 1e12
        for (var j = 0; j < all.length; j++) {
            var a = all[j].width * all[j].height
            if (a < best) { best = a; s = all[j] }
        }
        return s
    }

    // ── Onglets : catalogue dans core/TouchTabs.qml (ordre/activation : ShellState.touchTabs) ──
    readonly property var allTabs: TouchTabs.all

    readonly property var tabs: TouchTabs.tabs
    readonly property var visibleTabs: tabs.filter(t => t.on && (t.key !== "game" || GameMode.active))

    // Mode jeu : bascule sur la page Game au lancement, revient après.
    property string _pageBeforeGame: ""
    Connections {
        target: GameMode
        function onActiveChanged() {
            if (GameMode.active) {
                if (root.page !== "game") root._pageBeforeGame = root.page
                root.page = "game"
            } else if (root._pageBeforeGame !== "") {
                root.page = root._pageBeforeGame
                root._pageBeforeGame = ""
            }
        }
    }

    function saveTabs(list) { TouchTabs.save(list) }
    function toggleTab(i) {
        const l = tabs.slice()
        // Au moins un onglet reste actif.
        if (l[i].on && visibleTabs.length <= 1) return
        l[i] = Object.assign({}, l[i], { on: !l[i].on })
        saveTabs(l)
    }
    function moveTab(i, d) {
        const j = i + d
        if (j < 0 || j >= tabs.length) return
        const l = tabs.slice()
        const t = l[i]; l[i] = l[j]; l[j] = t
        saveTabs(l)
    }
    // Page courante désactivée → bascule sur le 1er onglet visible.
    onVisibleTabsChanged: if (!visibleTabs.some(t => t.key === page) && visibleTabs.length) page = visibleTabs[0].key

    property bool configOpen: false

    // ── Transition entre onglets : la page arrive du côté de l'onglet choisi ──
    property int _lastIdx: 0
    property int slideDir: 1
    onPageChanged: {
        const i = visibleTabs.findIndex(t => t.key === page)
        slideDir = i >= _lastIdx ? 1 : -1
        _lastIdx = i
        playPageAnim()
    }
    // Style choisi dans Réglages › Animations ([theme] page_anim)
    function playPageAnim() {
        switch (Appearance.pageAnim) {
        case "none":    return
        case "slide":   pageSlide.restart(); return
        case "fade":    pageFade.restart(); return
        case "zoom":    pageZoom.restart(); return
        case "rise":    pageRise.restart(); return
        case "curtain": pageCurtain.restart(); return
        case "bubble":  pageBubble.restart(); return
        case "iris":    pageIris.restart(); return
        case "bounce":  pageBounce.restart(); return
        case "flip":    pageFlip.restart(); return
        case "swirl":   pageSwirl.restart(); return
        // morph : les onglets à cartes (System, Apps) ouvrent déjà leurs cartes une à une
        default:        if (selfAnimated.indexOf(page) < 0) pageMorph.restart()
        }
    }
    readonly property var selfAnimated: ["stats", "deck"]
    // centre (x) de l'onglet actif, dans le repère de la zone de page : départ de la bulle
    function tabCenterX() {
        for (const c of tabRow.children)
            if (c.modelData && c.modelData.key === page) return c.mapToItem(pageArea, c.width / 2, 0).x
        return pageArea.width / 2
    }
    function stepTab(d) {
        const i = visibleTabs.findIndex(t => t.key === page)
        const j = Math.max(0, Math.min(visibleTabs.length - 1, i + d))
        if (j !== i) { page = visibleTabs[j].key; GameBreak.extend() }
    }

    // Palette wallust vive : chaque onglet cycle dessus (icône/label/pastille).
    readonly property var _wpal: [
        Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,
        Appearance.colors.color9,  Appearance.colors.color10, Appearance.colors.color11,
        Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14
    ]

    // ── Horloge (coin haut-droit) ────────────────────────────────────────────────
    property string clockH:    "--:--"
    property string clockDate: ""
    Timer {
        interval: 1000; running: ShellState.touchPanelOn; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            root.clockH    = Qt.formatTime(d, "HH:mm")
            root.clockDate = Qt.formatDate(d, "dddd d MMMM")
        }
    }

    // À l'ouverture : reset sur "home" + focaliser le Xeneon. Une fois le
    // moniteur tactile focalisé, les taps 1 doigt cliquent nativement (sinon il
    // faut le tap 2 doigts hyprgrass juste pour prendre le focus). `silent` des
    // lancements d'apps → le focus reste sur le Xeneon pendant la session.
    // Demande d'ouverture d'un onglet précis (ex. Réglages › Apps › « Voir l'onglet Apps »)
    function takeTouchPage() {
        if (Popups.touchPage === "") return
        const k = Popups.touchPage
        Popups.touchPage = ""
        if (root.visibleTabs.some(t => t.key === k)) root.page = k
    }
    Connections {
        target: Popups
        function onTouchPageChanged() { Qt.callLater(root.takeTouchPage) }
    }
    // `qs ipc call touch page <onglet>` : ouvrir un onglet depuis un script
    IpcHandler { target: "touch"; function page(p: string) { Popups.touchPage = p } }

    // Le Xeneon suit l'éditeur : une fenêtre d'éditeur de code qui passe au premier plan affiche l'onglet
    // Terminal, une fois par arrivée sur l'éditeur (jamais de retour automatique, rien en jeu). Toucher le
    // panneau ne compte pas : sans fenêtre active (focus sur le panneau), l'état précédent est gardé.
    // [touchpanel] follow_editors (oui/non), editor_apps (identifiants d'application, en minuscules).
    readonly property var editorApps: Config.get("touchpanel.editor_apps",
        ["windsurf", "code", "code-oss", "codium", "cursor", "zed", "dev.zed.zed", "kate", "jetbrains-idea", "jetbrains-pycharm"])
    // On retient la dernière fenêtre d'éditeur traitée : une fenêtre d'éditeur NOUVELLE (Windsurf relancé, alors
    // qu'il n'y avait plus aucune fenêtre active) bascule aussi, pas seulement le retour depuis une autre appli.
    property bool _wasEditor: false
    property var  _lastEditor: null
    Connections { target: ToplevelManager; function onActiveToplevelChanged() { root._followActive() } }
    function _followActive() {
        const t = ToplevelManager.activeToplevel
        if (!t) return
        const ed = root.editorApps.indexOf((t.appId || "").toLowerCase()) >= 0
        if (ed && (!root._wasEditor || t !== root._lastEditor) && Config.get("touchpanel.follow_editors", true)
            && !GameMode.active && root.tabs.some(x => x.key === "term" && x.on)) {
            console.log("[touch] éditeur au premier plan (" + t.appId + ") → Terminal")
            Popups.touchPage = "term"
        }
        if (ed) root._lastEditor = t
        root._wasEditor = ed
    }
    Process { id: focusProc }
    // valeur de cursor:no_warps de la config Hyprland, remise après le focus
    property string noWarps: "false"
    Process {
        running: true
        command: ["hyprctl", "getoption", "cursor:no_warps", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.noWarps = JSON.parse(text).bool ? "true" : "false" } catch (e) {} } }
    }
    Connections {
        target: ShellState
        function onTouchPanelOnChanged() {
            if (ShellState.touchPanelOn) {
                root.page = root.visibleTabs.length ? root.visibleTabs[0].key : "home"
                Qt.callLater(root.takeTouchPage)
                root.configOpen = false
                if (root.targetScreen) {
                    // no_warps coupé le temps du focus : le curseur reste où il est
                    // (Hyprland le ramènerait sinon sur le tactile), puis valeur de la config remise
                    focusProc.command = ["hyprctl", "eval",
                        "hl.config({ cursor = { no_warps = true } }); "
                        + "hl.dispatch(hl.dsp.focus({ monitor = [[" + root.targetScreen.name + "]] })); "
                        + "hl.config({ cursor = { no_warps = " + root.noWarps + " } })"]
                    focusProc.running = false
                    focusProc.running = true
                }
            }
        }
    }


    PanelWindow {
        id: win
        screen:  root.targetScreen
        visible: ShellState.touchPanelOn && root.targetScreen !== null

        WlrLayershell.layer:     WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:touchpanel"
        // Focus clavier à la demande (onglet Discord) — permet à un TextInput de
        // recevoir la frappe. NB : sans clavier physique, la saisie tactile passe
        // par l'OSK (à ajouter). Sur le Dashboard (écran principal) ça marche déjà.
        // OnDemand permanent : n'importe quel TextInput (recherche, Discord, Files…)
        // peut prendre le focus clavier au clic, sans le voler autrement.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: Appearance.colors.bg

        // ── Fond : wallpaper courant, flouté + voile sombre ────────────────────
        // En mode vidéo, currentWall est un .mp4 (non affichable par Image) → on
        // retombe sur la vignette statique écrite par set-video-wallpaper.sh.
        Image {
            id: bgWall
            anchors.fill: parent; visible: false
            cache: false
            // Fond fortement flouté → une basse résolution suffit largement et
            // économise beaucoup de mémoire texture (un 4K = ~35 Mo décodé).
            sourceSize.width: 1000
            // En jeu : bannière du jeu (cache Steam) au lieu du wallpaper.
            source: GameMode.active && GameMode.gameArt !== "" ? GameMode.gameArt
                : WallpaperState.videoMode
                ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
                : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
            fillMode: Image.PreserveAspectCrop
        }
        MultiEffect {
            anchors.fill: parent
            source: bgWall
            // Visible dès que la vignette/le wallpaper est chargé — indépendant de
            // currentWall (vide en mode vidéo), sinon écran noir sur une vidéo.
            visible: bgWall.status === Image.Ready
            blurEnabled: true; blur: 0.6; blurMax: 24; brightness: -0.15
        }
        // Voile sombre pour la lisibilité des cartes des pages.
        Rectangle { anchors.fill: parent; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6) }

        // ── Contenu : barre d'onglets + zone de page ───────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 20

            // ══ Barre du haut : onglets CENTRÉS + horloge/fermer à droite ══
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 72

                // Swipe horizontal sur la barre → onglet voisin (les taps passent).
                DragHandler {
                    target: null
                    yAxis.enabled: false
                    onActiveChanged: if (!active) {
                        if (translation.x < -80) root.stepTab(1)
                        else if (translation.x > 80) root.stepTab(-1)
                    }
                }

                // Onglets centrés horizontalement (droitier → main droite plus rapide).
                // Trop d'onglets pour la largeur → compact : seul l'onglet actif
                // garde son libellé, les autres = icône seule.
                Row {
                    id: tabRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter:   parent.verticalCenter
                    spacing: 10
                    // Police monospace : ~12 px/caractère à 20 px ; icône 30 + marges 52 + espacement.
                    readonly property real fullWidth: root.visibleTabs.reduce(
                        (w, t) => w + t.label.length * 12 + 30 + 52 + 10, 0)
                    readonly property bool compact: fullWidth > parent.width - 2 * (rightBlock.width + 24)
                    Repeater {
                        model: root.visibleTabs
                        delegate: Rectangle {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool isActive: root.page === modelData.key
                            readonly property color wcol: root._wpal[index % root._wpal.length]
                            // Éclaircie pour rester lisible sur fond sombre.
                            readonly property color wbright: Qt.lighter(wcol, 1.35)
                            width:  tabContent.implicitWidth + 40
                            height: 72
                            radius: 20
                            // Actif : pastille pleine dans la couleur wallust de l'onglet.
                            // Inactif : teinte douce de la même couleur.
                            color: isActive
                                ? ColorUtils.applyAlpha(wbright, 0.9)
                                : ColorUtils.applyAlpha(wbright, 0.16)
                            border.color: isActive ? "transparent" : ColorUtils.applyAlpha(wbright, 0.5)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }

                            Row {
                                id: tabContent
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.family: Appearance.font.family; font.pixelSize: 30
                                    color: tab.isActive ? Appearance.colors.bg : tab.wbright
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !tabRow.compact || tab.isActive
                                    text: modelData.label
                                    font.family: Appearance.font.family; font.pixelSize: 20
                                    font.weight: tab.isActive ? Font.Bold : Font.Medium
                                    color: tab.isActive ? Appearance.colors.bg : Appearance.colors.fg
                                }
                            }
                            // Point d'alerte sur l'onglet Santé quand quelque chose ne répond pas
                            Rectangle {
                                visible: tab.modelData.key === "health" && Health.failCount > 0
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                width: 14; height: 14; radius: 7
                                color: Appearance.colors.color13
                                border.width: 2; border.color: Appearance.colors.bg
                            }
                            // GameBreak.extend() : naviguer dans le panneau relance le
                            // compte à rebours de la pause jeu (sinon on est renvoyé
                            // au jeu en plein milieu d'une manip).
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root.page = modelData.key; GameBreak.extend() }
                            }
                        }
                    }
                }

                // Horloge + bouton fermer, ancrés à droite.
                Row {
                    id: rightBlock
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    // Config des onglets (activer / réordonner).
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56; height: 56; radius: 16
                        color: root.configOpen ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                               : ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                        Text {
                            anchors.centerIn: parent; text: "󰒓"
                            font.family: Appearance.font.family; font.pixelSize: 26
                            color: root.configOpen ? Appearance.colors.bg : Appearance.colors.fg
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.configOpen = !root.configOpen; GameBreak.extend() } }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            anchors.right: parent.right
                            text: root.clockH
                            font.family: Appearance.font.family; font.pixelSize: 34; font.weight: Font.Bold
                            color: Appearance.colors.fg
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.clockDate
                            font.family: Appearance.font.family; font.pixelSize: 14
                            color: Appearance.colors.dim
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 72; radius: 20
                        color: closeHov.hovered ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                                : ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                        Text {
                            anchors.centerIn: parent; text: "󰅖"
                            font.family: Appearance.font.family; font.pixelSize: 30
                            color: closeHov.hovered ? Appearance.colors.bg : Appearance.colors.fg
                        }
                        HoverHandler { id: closeHov }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.touchPanelOn = false }
                    }
                }
            }

            // ══ Zone de page — réutilise directement les pages du Dashboard ══
            Item {
                id: pageArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true                       // la bulle géante reste dans la zone de page
                transform: Translate { id: pageShift }

                ParallelAnimation {
                    id: pageSlide
                    NumberAnimation {
                        target: pageShift; property: "x"
                        from: root.slideDir * 90; to: 0
                        duration: Appearance.dur(280); easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: pageArea; property: "opacity"
                        from: 0.25; to: 1
                        duration: Appearance.dur(240); easing.type: Easing.OutQuad
                    }
                }

                // Page zoomée : le contenu est mis en page dans une boîte logique
                // (taille / s) puis mise à l'échelle s → remplit toute la zone en
                // plus grand. Texte distance-field → reste net.
                component ScaledPage: Item {
                    id: sp
                    property real s: 1.0
                    anchors.fill: parent
                    default property alias content: holder.data
                    Item {
                        id: holder
                        width:  sp.width  > 0 ? sp.width  / sp.s : 0
                        height: sp.height > 0 ? sp.height / sp.s : 0
                        transformOrigin: Item.TopLeft
                        scale: sp.s
                    }
                }

                // ── Ouverture d'onglet : la page sort d'une goutte qui s'étire puis se déroule ──
                readonly property real dot: 26
                property real mw: width
                property real mh: height
                property real my: 0
                property real frame: 0           // fond + contour de la forme pendant l'animation
                property real shown: 1
                property real rad: 22            // arrondi de la forme pendant l'animation
                property bool vcenter: false     // forme centrée verticalement (iris)
                property bool circle: false      // forme ronde de diamètre d centrée en (cx, cy) (bulle)
                property real cx: 0
                property real cy: 0
                property real d: 0
                SequentialAnimation {
                    id: pageMorph
                    ScriptAction { script: { pageArea.mw = pageArea.dot; pageArea.mh = pageArea.dot; pageArea.my = -pageArea.dot; pageArea.frame = 1; pageArea.shown = 0 } }
                    NumberAnimation { target: pageArea; property: "my"; to: 0; duration: Appearance.dur(260); easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageArea; property: "mw"; to: pageArea.width; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                    ParallelAnimation {
                        NumberAnimation { target: pageArea; property: "mh"; to: pageArea.height; duration: Appearance.dur(480); easing.type: Easing.OutBack; easing.overshoot: 1.05 }
                        SequentialAnimation {
                            PauseAnimation { duration: Appearance.dur(180) }
                            NumberAnimation { target: pageArea; property: "shown"; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
                        }
                    }
                    NumberAnimation { target: pageArea; property: "frame"; to: 0; duration: Appearance.dur(260) }
                    ScriptAction { script: { pageArea.mw = Qt.binding(() => pageArea.width); pageArea.mh = Qt.binding(() => pageArea.height) } }
                }

                // fondu
                NumberAnimation { id: pageFade; target: pageArea; property: "shown"; from: 0; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutQuad }
                // zoom : la page grossit depuis 92 %
                ParallelAnimation {
                    id: pageZoom
                    NumberAnimation { target: pageContent; property: "scale"; from: 0.92; to: 1; duration: Appearance.dur(380); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    NumberAnimation { target: pageArea; property: "shown"; from: 0; to: 1; duration: Appearance.dur(260) }
                }
                // montée : la page arrive du bas
                ParallelAnimation {
                    id: pageRise
                    NumberAnimation { target: riseShift; property: "y"; from: 60; to: 0; duration: Appearance.dur(380); easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageArea; property: "shown"; from: 0; to: 1; duration: Appearance.dur(300) }
                }
                // rideau : la page se déroule de haut en bas sur toute la largeur
                SequentialAnimation {
                    id: pageCurtain
                    ScriptAction { script: { pageArea.mw = pageArea.width; pageArea.mh = 0; pageArea.my = 0; pageArea.frame = 1; pageArea.shown = 1 } }
                    NumberAnimation { target: pageArea; property: "mh"; to: pageArea.height; duration: Appearance.dur(520); easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageArea; property: "frame"; to: 0; duration: Appearance.dur(220) }
                    ScriptAction { script: { pageArea.mh = Qt.binding(() => pageArea.height) } }
                }

                // bulle : un cercle naît sous l'onglet touché et gonfle jusqu'à couvrir la page
                SequentialAnimation {
                    id: pageBubble
                    ScriptAction { script: { pageArea.cx = root.tabCenterX(); pageArea.cy = 0; pageArea.d = 0
                                             pageArea.circle = true; pageArea.frame = 1; pageArea.shown = 1 } }
                    NumberAnimation { target: pageArea; property: "d"; to: 2.1 * Math.hypot(pageArea.width, pageArea.height)
                                      duration: Appearance.dur(700); easing.type: Easing.InOutCubic }
                    ScriptAction { script: pageArea.circle = false }
                    NumberAnimation { target: pageArea; property: "frame"; to: 0; duration: Appearance.dur(160) }
                }
                // iris : une fente s'ouvre au centre comme un œil, ses bords ronds se redressent
                SequentialAnimation {
                    id: pageIris
                    ScriptAction { script: { pageArea.vcenter = true; pageArea.mw = 0; pageArea.mh = pageArea.height * 0.3
                                             pageArea.rad = pageArea.height; pageArea.frame = 1; pageArea.shown = 1 } }
                    ParallelAnimation {
                        NumberAnimation { target: pageArea; property: "mw"; to: pageArea.width; duration: Appearance.dur(620); easing.type: Easing.OutCubic }
                        NumberAnimation { target: pageArea; property: "mh"; to: pageArea.height; duration: Appearance.dur(620); easing.type: Easing.InOutCubic }
                        NumberAnimation { target: pageArea; property: "rad"; to: 22; duration: Appearance.dur(620); easing.type: Easing.InCubic }
                    }
                    NumberAnimation { target: pageArea; property: "frame"; to: 0; duration: Appearance.dur(220) }
                    ScriptAction { script: { pageArea.vcenter = false; pageArea.mw = Qt.binding(() => pageArea.width); pageArea.mh = Qt.binding(() => pageArea.height) } }
                }
                // rebond : la page tombe d'en haut et rebondit en se posant
                ParallelAnimation {
                    id: pageBounce
                    NumberAnimation { target: riseShift; property: "y"; from: -pageArea.height * 0.45; to: 0; duration: Appearance.dur(820); easing.type: Easing.OutBounce }
                    NumberAnimation { target: pageArea; property: "shown"; from: 0; to: 1; duration: Appearance.dur(220) }
                }
                // carte : la page pivote sur elle-même comme une carte qu'on retourne
                ParallelAnimation {
                    id: pageFlip
                    NumberAnimation { target: flipRot; property: "angle"; from: 88; to: 0; duration: Appearance.dur(640); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    NumberAnimation { target: pageContent; property: "scale"; from: 0.9; to: 1; duration: Appearance.dur(640); easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageArea; property: "shown"; from: 0.2; to: 1; duration: Appearance.dur(300) }
                }
                // tourbillon : la page arrive en spirale depuis le centre en grossissant
                ParallelAnimation {
                    id: pageSwirl
                    NumberAnimation { target: spinRot; property: "angle"; from: -35; to: 0; duration: Appearance.dur(680); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: pageContent; property: "scale"; from: 0.35; to: 1; duration: Appearance.dur(680); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: pageArea; property: "shown"; from: 0; to: 1; duration: Appearance.dur(360) }
                }

                ClippingRectangle {
                    id: morphBox
                    x: pageArea.circle ? pageArea.cx - pageArea.d / 2 : (pageArea.width - pageArea.mw) / 2
                    y: pageArea.circle ? pageArea.cy - pageArea.d / 2 : pageArea.vcenter ? (pageArea.height - pageArea.mh) / 2 : pageArea.my
                    width: pageArea.circle ? pageArea.d : pageArea.mw
                    height: pageArea.circle ? pageArea.d : pageArea.mh
                    radius: pageArea.circle ? pageArea.d / 2 : pageArea.frame > 0 ? Math.min(pageArea.rad, Math.min(width, height) / 2) : 0
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.85 * pageArea.frame)
                    border.width: pageArea.frame > 0 ? 1 : 0
                    border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.6 * pageArea.frame)

                    // le contenu reste en place pendant que la forme grandit autour de lui
                    Item {
                        id: pageContent
                        x: -morphBox.x; y: -morphBox.y
                        width: pageArea.width; height: pageArea.height
                        opacity: pageArea.shown
                        transform: [
                            Translate { id: riseShift },
                            Rotation { id: flipRot; origin.x: pageContent.width / 2; origin.y: pageContent.height / 2; axis { x: 0; y: 1; z: 0 } },
                            Rotation { id: spinRot; origin.x: pageContent.width / 2; origin.y: pageContent.height / 2 }
                        ]

                // Une page par entrée du catalogue. Chargée à la demande (Loader) et
                // libérée quand l'onglet n'est pas affiché, sauf `keep: true`.
                Repeater {
                    model: root.allTabs
                    delegate: ScaledPage {
                        required property var modelData
                        visible: root.page === modelData.key
                        s: Config.pageScale(modelData.key, modelData.scale ?? 1.0)   // config.toml > catalogue
                        Loader {
                            anchors.fill: parent
                            active: (modelData.keep ?? false) || root.page === modelData.key
                            source: Qt.resolvedUrl(modelData.src)
                        }
                    }
                }
                    }
                }
            }
        }

        // ══ Config des onglets : une carte par onglet, dans l'ordre de la barre ══
        // Tap interrupteur = activer/désactiver ; ◀ ▶ = déplacer. Sauvé à chaque
        // changement (ShellState.touchTabs → user_data/shell_state.json).
        Rectangle {
            anchors.fill: parent
            visible: root.configOpen
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.75)
            MouseArea { anchors.fill: parent; onClicked: root.configOpen = false }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Onglets — glisser pour parcourir, tap pour activer, ◀ ▶ pour réorganiser"
                    font.family: Appearance.font.family; font.pixelSize: 22; font.weight: Font.Bold
                    color: Appearance.colors.fg
                }

                // Carrousel (même esprit que le sélecteur de fonds) : glisser au doigt ou à la molette, toucher une
                // carte la centre ; la carte du centre en grand, les voisines réduites et inclinées. ListView et pas
                // PathView : pas de boucle, l'ordre des onglets reste lisible de gauche à droite.
                ListView {
                    id: tabView
                    width: parent.parent.width; height: 340
                    orientation: ListView.Horizontal
                    model: root.tabs
                    spacing: 14
                    clip: true
                    preferredHighlightBegin: width / 2 - 84; preferredHighlightEnd: width / 2 + 84
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: Appearance.dur(320)
                    snapMode: ListView.SnapToItem
                    boundsBehavior: Flickable.StopAtBounds
                    // après un déplacement ou un interrupteur, le modèle est recréé (index remis à 0) : on recentre
                    // la carte touchée, mémorisée au moment du toucher (pas via currentIndex, déjà remis à 0 ici)
                    property int keep: 0
                    // molette : un cran (120) = une carte ; les petits pas d'un pavé tactile sont cumulés
                    property real wheelAcc: 0
                    WheelHandler {
                        onWheel: (e) => {
                            tabView.wheelAcc += e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
                            while (Math.abs(tabView.wheelAcc) >= 120) {
                                const step = tabView.wheelAcc < 0 ? 1 : -1
                                tabView.wheelAcc += step * 120
                                tabView.currentIndex = Math.max(0, Math.min(tabView.count - 1, tabView.currentIndex + step))
                            }
                            GameBreak.extend()
                        }
                    }
                    onModelChanged: Qt.callLater(() => { tabView.positionViewAtIndex(Math.min(keep, count - 1), ListView.Center)
                                                         tabView.currentIndex = Math.min(keep, count - 1) })
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property color wcol: Qt.lighter(root._wpal[index % root._wpal.length], 1.35)
                            // distance au centre, en cartes : échelle, opacité et inclinaison
                            readonly property real dist: (x + width / 2 - tabView.contentX - tabView.width / 2) / (width + tabView.spacing)
                            readonly property real ad: Math.min(Math.abs(dist), 4)
                            // carte centrale agrandie (×1,2), puis décroissance douce vers les bords
                            scale: ad < 1 ? 1.2 - ad * 0.3 : 0.9 - (ad - 1) * 0.08
                            z: 10 - ad
                            transform: Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 }
                                                  angle: Math.max(-40, Math.min(40, -card.dist * 14)) }
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined   // y est ignoré par ListView
                            width: 168; height: 250; radius: 20
                            color: modelData.on ? ColorUtils.applyAlpha(wcol, 0.22) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                            border.width: modelData.on ? 2 : 1
                            border.color: modelData.on ? wcol : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                            opacity: (modelData.on ? 1 : 0.55) * (1 - ad * 0.16)
                            Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                            MouseArea { anchors.fill: parent; onClicked: tabView.currentIndex = card.index   // centre (et ne ferme pas)
                                        onWheel: (w) => w.accepted = false }          // une MouseArea garde la molette : on la laisse au carrousel

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top; anchors.topMargin: 18
                                spacing: 8
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.icon
                                    font.family: Appearance.font.family; font.pixelSize: 42
                                    color: card.modelData.on ? card.wcol : Appearance.colors.dim
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.label
                                    font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                                    color: Appearance.colors.fg
                                }
                                // Interrupteur
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 76; height: 40; radius: 20
                                    color: card.modelData.on ? card.wcol : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        y: 4; x: card.modelData.on ? parent.width - width - 4 : 4
                                        color: Appearance.colors.bg
                                        Behavior on x { NumberAnimation { duration: Appearance.dur(120) } }
                                    }
                                    MouseArea { anchors.fill: parent; anchors.margins: -10; onWheel: (w) => w.accepted = false
                                                 onClicked: { tabView.keep = card.index; root.toggleTab(card.index); GameBreak.extend() } }
                                }
                            }

                            // ◀ ▶ déplacer
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                                spacing: 12
                                Repeater {
                                    model: [ { g: "󰁍", d: -1 }, { g: "󰁔", d: 1 } ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool can: card.index + modelData.d >= 0 && card.index + modelData.d < root.tabs.length
                                        width: 64; height: 52; radius: 14
                                        opacity: can ? 1 : 0.25
                                        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7)
                                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                                        Text {
                                            anchors.centerIn: parent; text: parent.modelData.g
                                            font.family: Appearance.font.family; font.pixelSize: 24
                                            color: Appearance.colors.fg
                                        }
                                        MouseArea {
                                            anchors.fill: parent; enabled: parent.can
                                            onWheel: (w) => w.accepted = false
                                            onClicked: { tabView.keep = card.index + parent.modelData.d; root.moveTab(card.index, parent.modelData.d); GameBreak.extend() }
                                        }
                                    }
                                }
                            }
                        }
                }

                // Réinitialiser l'ordre/état par défaut.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: resetRow.implicitWidth + 40; height: 56; radius: 16
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    Row {
                        id: resetRow
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "󰑓"; font.family: Appearance.font.family; font.pixelSize: 22; color: Appearance.colors.fg }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Par défaut"; font.family: Appearance.font.family; font.pixelSize: 17
                            color: Appearance.colors.fg
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.touchTabs = [] }
                }

            }
        }

    }
}
