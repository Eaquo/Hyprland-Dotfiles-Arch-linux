import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// Menu — le cadre des menus Quick-Bar (remplace rofi). Voir menus/README.md.
//   menus/qbmenu            commande (même usage que `rofi -dmenu`, + `qbmenu run <script>`)
//   menus/templates/*.qml   mises en page (List, Grid, Emoji, Input, Confirm, Apps, Files, Info, Theme)
//   menus/scripts/*.sh      menus écrits en quelques variables + items() + on_select()
// Le cadre gère fenêtre, position, taille, recherche, clavier, animations et la réponse
// (écrite dans req.out : "code\ntexte" ; 0 choisi, 1 annulé, 10+ touches perso).
PanelWindow {
    id: root

    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }
    color: "transparent"
    visible: shown
    // fenêtre plein écran entièrement transparente (rien n'est affiché autour de la boîte, pas de voile) :
    // un clic à côté de la boîte la ferme, comme rofi. La boîte se place selon POSITION.
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:menu"
    // garde le clavier pendant la fermeture : un menu qui se rouvre aussitôt (retour, onglet, sous-menu) ne le perd pas
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── ce que voient les templates ───────────────────────────────────────
    property var req: ({})
    property string query: ""
    property int cur: 0
    property bool settled: false
    // survol pris en compte seulement après l'ouverture (sinon l'élément sous le curseur se sélectionne seul)
    property bool hoverReady: false
    Timer { id: hoverT; interval: 500; onTriggered: root.hoverReady = true }         // ouverture finie : plus de cascade à chaque frappe
    readonly property string tpl: req.template || "list"
    property var extra: []               // éléments fournis par le template (ex. Apps)
    property var liveItems: []
    readonly property var source: extra.length ? extra : req.live ? liveItems : (req.items || [])
    readonly property bool filtering: view.item ? view.item.filter !== false : true
    readonly property var items: {
        if (req.live || !filtering || query.trim() === "") return source
        const q = query.toLowerCase().trim(), words = q.split(/\s+/)
        const hit = source.filter(it => !isHead(it) && words.every(w => (it.t + " " + (it.sub || "")).toLowerCase().indexOf(w) >= 0))
        return hit.filter(it => it.t.toLowerCase().startsWith(q)).concat(hit.filter(it => !it.t.toLowerCase().startsWith(q)))
    }
    // texte avec les caractères trouvés surlignés (gras, couleur du menu) — pour Text.StyledText
    function mark(str, col) {
        const esc = x => x.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const words = query.toLowerCase().trim().split(/\s+/).filter(w => w !== "")
        if (!words.length) return esc(str)
        const low = str.toLowerCase(), hit = new Array(str.length).fill(false)
        for (const w of words) { const i = low.indexOf(w); if (i >= 0) for (let k = i; k < i + w.length; k++) hit[k] = true }
        let out = "", on = false
        for (let k = 0; k < str.length; k++) {
            if (hit[k] !== on) { out += hit[k] ? "<b><font color=\"" + (col || glow) + "\">" : "</font></b>"; on = hit[k] }
            out += esc(str[k])
        }
        return out + (on ? "</font></b>" : "")
    }
    // arrondi proportionnel à celui de la barre ([bar] radius / demi-hauteur : 100 % = pilules complètes) ;
    // les grands éléments (tuiles, bandeau, boîte) sont plafonnés pour ne pas devenir des cercles
    readonly property real radRatio: Appearance.bar.maxRadius > 0 ? Math.max(0, Math.min(1, Appearance.bar.radius / Appearance.bar.maxRadius)) : 0.5
    function rad(h) { return Math.min(radRatio * h / 2, 12 + radRatio * 20) }
    function isHead(it) { return it.nonselectable === "true" || it.nonselectable === true }
    function selectable(i) { return i >= 0 && i < items.length && !isHead(items[i]) }
    function step(d) {
        let i = cur
        while (true) {
            const n = Math.max(0, Math.min(items.length - 1, i + d))
            if (n === i) return
            i = n
            if (selectable(i)) { cur = i; return }
        }
    }
    onItemsChanged: { cur = Math.min(Math.max(0, req.selected || 0), Math.max(0, items.length - 1)); req.selected = 0; if (!selectable(cur)) step(1) }
    function iconSrc(ic) {
        if (!ic) return ""
        if (ic.startsWith("/")) return "file://" + ic
        if (ic.startsWith("file:") || ic.startsWith("image:")) return ic
        return Quickshell.iconPath(ic, true)
    }
    function choose(i) {
        if (!selectable(i)) return
        const it = items[i]
        if (it.entry) it.entry.execute()           // Apps : lancement direct
        finish(0, it.id || it.t)
    }

    // ── ouverture / réponse ───────────────────────────────────────────────
    property bool open: false
    property bool shown: false
    Process { id: loadProc; stdout: StdioCollector { onStreamFinished: { try { root.start(JSON.parse(text)) } catch (e) {} root.loading = false } } }
    // créé par un LazyLoader (shell.qml) à la première demande, détruit après la fermeture : aucune RAM fermé.
    // Les commandes IPC « menu » sont dans shell.qml et passent par loadPath().
    property bool loading: false
    function loadPath(path) { loading = true; loadProc.command = ["cat", path]; loadProc.running = true }
    // différé : changer menuRequest pendant la création relancerait la liaison « active » du LazyLoader
    Component.onCompleted: if (Popups.menuRequest !== "") loadPath(Popups.menuRequest)   // remise à zéro par shell.qml
    readonly property var tabs: req.tabs || []
    Process { id: tabProc }
    function switchTab(i) {
        if (i < 0 || i >= tabs.length || tabs[i].run === req.tab) return
        tabProc.command = ["setsid", "-f", Quickshell.shellDir + "/menus/run.sh", tabs[i].run]
        tabProc.running = false; tabProc.running = true
    }
    function start(r) {
        const swap = open                        // déjà ouvert (onglet) : on garde la carte, on change le contenu
        if (open) reply(1, "")                   // une nouvelle demande remplace la précédente
        req = r; query = ""; liveItems = []; extra = []
        hoverReady = false; hoverT.restart()
        if (swap) {
            const name0 = tpl.charAt(0).toUpperCase() + tpl.slice(1)
            view.setSource(Quickshell.shellDir + "/menus/templates/" + name0 + ".qml", { menu: root })
            if (r.live) runLive()
            field.text = ""; field.forceActiveFocus()
            swapAnim.restart()
            return
        }
        settled = false
        crtX = 1; crtY = 1; flash = 0; gl = 0; draw = 1; bgA = 1; scan = -1; fade = 1
        // état de départ du style, posé AVANT l'affichage (sinon 1re image à pleine taille, puis l'animation)
        if (style === "matrix") { crtX = 0; crtY = 0.004 }
        else if (style === "cyber") fade = 0
        else if (style === "jarvis") { draw = 0; bgA = 0 }
        else if (style === "minimal") { fade = 0; crtX = 0.96; crtY = 0.96 }
        mw = 2; mh = 2; intro = 0
        const name = tpl.charAt(0).toUpperCase() + tpl.slice(1)
        view.setSource(Quickshell.shellDir + "/menus/templates/" + name + ".qml", { menu: root })
        if (r.live) runLive()
        open = true; shown = true; closeT.stop()
        field.text = ""; field.forceActiveFocus()
        stopAll()
        ;(({ matrix: mxIn, cyber: cyIn, jarvis: jvIn, minimal: miIn })[style] || inAnim).restart()
    }
    function stopAll() { [inAnim, outAnim, mxIn, mxOut, cyIn, cyOut, jvIn, jvOut, miIn, miOut].forEach(a => a.stop()) }
    NumberAnimation { id: swapAnim; target: root; property: "intro"; from: 0.2; to: 1; duration: Appearance.dur(260); easing.type: Easing.OutCubic }
    Process { id: replyProc }
    function reply(code, text) {
        if (!req.out) return
        replyProc.command = ["sh", "-c", 'printf "%s\\n%s" "$1" "$2" > "$3.tmp" && mv "$3.tmp" "$3"', "_", String(code), text, req.out]
        replyProc.running = false; replyProc.running = true
    }
    function finish(code, text) {
        if (!open) return
        reply(code, text)
        open = false
        stopAll(); settled = false
        ;(({ matrix: mxOut, cyber: cyOut, jarvis: jvOut, minimal: miOut })[style] || outAnim).restart()
        closeT.restart()
    }
    function accept(custom) {
        const typed = !req.noCustom && query !== ""
        if (custom || tpl === "input" && !req.live || !items.length) { if (typed || tpl === "input") finish(0, query); return }
        choose(cur)
    }
    Timer { id: closeT; interval: Appearance.dur(420); onTriggered: { root.shown = false; view.source = "" } }

    // --live : relancé à chaque frappe, la saisie en $1
    Process { id: liveProc; stdout: StdioCollector { onStreamFinished: root.liveItems = text.split("\n").filter(l => l !== "").map(l => ({ t: l })) } }
    function runLive() { liveProc.running = false; liveProc.command = ["sh", "-c", req.live, "qbmenu", query]; liveProc.running = true }
    Timer { id: liveT; interval: 120; onTriggered: root.runLive() }
    onQueryChanged: if (req.live) liveT.restart()

    // ── couleur : dominante de l'image choisie (comme SUPER+W), sinon l'accent ──
    readonly property color accentGlow: Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                        ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent
    property color glow: accentGlow
    Behavior on glow { ColorAnimation { duration: Appearance.dur(300) } }
    readonly property var curItem: items[cur] || null
    Canvas {
        id: sampler
        width: 16; height: 16; visible: false
        readonly property string ic: root.curItem && root.curItem.icon && root.tpl !== "apps" ? root.curItem.icon : ""
        property string src: ic.startsWith("/") ? "file://" + ic : ic.startsWith("file:") ? ic : ""
        onSrcChanged: { if (src !== "") loadImage(src); else root.glow = root.accentGlow }
        onImageLoaded: requestPaint()
        onPaint: {
            if (!src) return
            const g = getContext("2d"); g.clearRect(0, 0, 16, 16); g.drawImage(src, 0, 0, 16, 16)
            const d = g.getImageData(0, 0, 16, 16).data
            let best = [128, 128, 128], score = -1
            for (let i = 0; i < d.length; i += 4) {
                const mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2])
                const sc = (mx ? (mx - mn) / mx : 0) * (0.4 + 0.6 * mx / 255)
                if (sc > score) { score = sc; best = [d[i], d[i + 1], d[i + 2]] }
            }
            const c = Qt.rgba(best[0] / 255, best[1] / 255, best[2] / 255, 1)
            root.glow = Appearance.contrastRatio(c, Appearance.colors.bg) < 3 ? Qt.lighter(c, 1.5) : c
        }
    }

    // ── taille et position ────────────────────────────────────────────────
    readonly property bool hasMesg: (req.mesg || "") !== ""
    readonly property bool hasSearch: view.item ? view.item.search !== false : true
    readonly property real contentH: view.item ? Math.min(view.item.contentH, req.height > 0 ? req.height : 1e6) : 0
    // menus à onglets : même largeur pour tous (celle du lanceur d'apps), pas de saut en changeant d'onglet
    readonly property real fullW: Math.min(req.width > 0 ? req.width : tabs.length ? 1720 : (view.item ? view.item.prefW : 900),
                                           (screen ? screen.width : 1920) - 120)
    readonly property real headH: 128
    readonly property real footH: 72
    readonly property real fullH: headH + (hasMesg ? 60 : 0) + contentH + footH
    readonly property string pos: req.position || "center"
    readonly property real margin: 70
    readonly property real cardX: pos.indexOf("left") >= 0 ? margin : pos.indexOf("right") >= 0 ? width - fullW - margin : (width - fullW) / 2
    readonly property real cardY: pos.startsWith("top") ? margin : pos.startsWith("bottom") ? height - fullH - margin : (height - fullH) / 2
    property real mw: 2
    property real mh: 2
    property real intro: 0
    SequentialAnimation {
        id: inAnim
        ScriptAction { script: { root.mw = 2; root.mh = 2; root.intro = 0 } }
        NumberAnimation { target: root; property: "mw"; to: root.fullW * 0.7; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: root; property: "mw"; to: root.fullW; duration: Appearance.dur(260); easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: root.fullH; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(180) }
                NumberAnimation { target: root; property: "intro"; to: 1; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: { root.mw = Qt.binding(() => root.fullW); root.mh = Qt.binding(() => root.fullH); root.settled = true } }
    }
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: root; property: "intro"; to: 0; duration: Appearance.dur(130) }
        NumberAnimation { target: root; property: "mh"; to: 46; duration: Appearance.dur(240); easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mw"; to: 2; duration: Appearance.dur(200); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "mh"; to: 2; duration: Appearance.dur(200); easing.type: Easing.InCubic }
        }
    }
    Behavior on mh { enabled: root.settled; NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutCubic } }
    Behavior on mw { enabled: root.settled; NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutCubic } }

    // ── animations selon le style (celui de l'écran de session, ou [menu] style) ──
    readonly property string style: String(Config.get("menu.style", Config.get("session.style", "matrix")))
    property real crtX: 1            // matrix : allumage cathodique
    property real crtY: 1
    property real flash: 0
    property real gl: 0              // cyber : force du glitch
    property real draw: 1            // jarvis : contour tracé (0 → 1)
    property real bgA: 1             //          fond qui apparaît
    property real scan: -1           //          ligne de balayage (0 → 1, -1 = aucune)
    property real fade: 1            // cyber / minimal : opacité de la carte
    property int tick: 0
    readonly property color opp: glow.hslSaturation < 0.12 ? Qt.hsla(0.98, 0.8, 0.6, 1) : Qt.hsla((glow.hslHue + 0.5) % 1, 0.85, 0.62, 1)
    FrameAnimation {
        running: root.shown && root.gl > 0
        onTriggered: root.tick++
    }
    function fullNow() { mw = Qt.binding(() => fullW); mh = Qt.binding(() => fullH) }
    function done() { fullNow(); settled = true }
    onCurChanged: {
        if (!settled) return
        if (style === "cyber") glSel.restart()
    }
    SequentialAnimation { id: glSel
        NumberAnimation { target: root; property: "gl"; to: 0.55; duration: 30 }
        NumberAnimation { target: root; property: "gl"; to: 0; duration: 160 } }
    Timer {   // petits glitchs au hasard (Netrunner)
        running: root.open && root.style === "cyber" && Appearance.animationsEnabled
        interval: 3000; repeat: true
        onTriggered: { interval = 1800 + Math.random() * 3500; glBurst.restart() }
    }
    SequentialAnimation { id: glBurst
        NumberAnimation { target: root; property: "gl"; to: 1; duration: 40 }
        NumberAnimation { target: root; property: "gl"; to: 0.3; duration: 60 }
        NumberAnimation { target: root; property: "gl"; to: 0.9; duration: 40 }
        NumberAnimation { target: root; property: "gl"; to: 0; duration: 200 } }

    // Matrix : un trait lumineux, l'écran s'ouvre, les textes se déchiffrent
    SequentialAnimation { id: mxIn
        ScriptAction { script: { root.fullNow(); root.crtX = 0; root.crtY = 0.004; root.intro = 0 } }
        NumberAnimation { target: root; property: "crtX"; to: 1; duration: Appearance.dur(170); easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 1; duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: root; property: "flash"; from: 0.6; to: 0; duration: Appearance.dur(420) }
            NumberAnimation { target: root; property: "intro"; to: 1; duration: Appearance.dur(260) }
        }
        ScriptAction { script: root.done() } }
    SequentialAnimation { id: mxOut
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtY"; to: 0.004; duration: Appearance.dur(170); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "flash"; to: 0.5; duration: Appearance.dur(170) } }
        NumberAnimation { target: root; property: "crtX"; to: 0; duration: Appearance.dur(150); easing.type: Easing.InCubic } }

    // Netrunner : la carte surgit dans un glitch, split RVB, textes brouillés
    SequentialAnimation { id: cyIn
        ScriptAction { script: { root.fullNow(); root.fade = 0; root.intro = 0 } }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "fade"; to: 1; duration: 50 }
                NumberAnimation { target: root; property: "fade"; to: 0.4; duration: 50 }
                NumberAnimation { target: root; property: "fade"; to: 1; duration: 60 } }
            SequentialAnimation {
                NumberAnimation { target: root; property: "gl"; to: 1; duration: 50 }
                NumberAnimation { target: root; property: "gl"; to: 0.3; duration: 70 }
                NumberAnimation { target: root; property: "gl"; to: 0.9; duration: 50 }
                NumberAnimation { target: root; property: "gl"; to: 0; duration: 240 } }
            NumberAnimation { target: root; property: "intro"; to: 1; duration: Appearance.dur(200) }
        }
        ScriptAction { script: root.done() } }
    SequentialAnimation { id: cyOut
        NumberAnimation { target: root; property: "gl"; to: 1; duration: 50 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "fade"; to: 0; duration: Appearance.dur(220); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "gl"; to: 0.4; duration: Appearance.dur(220) } } }

    // Jarvis : le contour se trace, puis un balayage révèle le contenu
    SequentialAnimation { id: jvIn
        ScriptAction { script: { root.fullNow(); root.draw = 0; root.bgA = 0; root.intro = 0; root.scan = -1 } }
        NumberAnimation { target: root; property: "draw"; to: 1; duration: Appearance.dur(460); easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "bgA"; to: 1; duration: Appearance.dur(300) }
            NumberAnimation { target: root; property: "scan"; from: 0; to: 1; duration: Appearance.dur(560); easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "intro"; to: 1; duration: Appearance.dur(500) }
        }
        ScriptAction { script: { root.scan = -1; root.done() } } }
    SequentialAnimation { id: jvOut
        NumberAnimation { target: root; property: "intro"; to: 0; duration: Appearance.dur(120) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "bgA"; to: 0; duration: Appearance.dur(200) }
            NumberAnimation { target: root; property: "draw"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic } } }

    // Minimal : fondu, léger zoom, contenu en cascade
    SequentialAnimation { id: miIn
        ScriptAction { script: { root.fullNow(); root.fade = 0; root.crtX = 0.96; root.crtY = 0.96; root.intro = 1 } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "fade"; to: 1; duration: Appearance.dur(360) }
            NumberAnimation { target: root; property: "crtX"; to: 1; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "crtY"; to: 1; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: Appearance.dur(250) }
        ScriptAction { script: root.done() } }
    SequentialAnimation { id: miOut
        ParallelAnimation {
            NumberAnimation { target: root; property: "fade"; to: 0; duration: Appearance.dur(260) }
            NumberAnimation { target: root; property: "crtX"; to: 0.97; duration: Appearance.dur(260) }
            NumberAnimation { target: root; property: "crtY"; to: 0.97; duration: Appearance.dur(260) } } }

    // ── voile, halo ───────────────────────────────────────────────────────
    MouseArea { anchors.fill: parent; onClicked: root.finish(1, "") }
    Item {
        id: fxc
        anchors.fill: parent
        opacity: root.fade
        transform: [
            Scale { origin.x: fxc.width / 2; origin.y: fxc.height / 2; xScale: root.crtX; yScale: root.crtY },
            Translate { x: { root.tick; return (Math.random() - 0.5) * 24 * root.gl } }
        ]
        // Netrunner : fantômes RVB décalés + tranche
        Repeater {
            model: 2
            Rectangle {
                required property int index
                visible: root.gl > 0.02
                x: box.x + (index ? 1 : -1) * 10 * root.gl; y: box.y + (index ? -1 : 1) * 3 * root.gl
                width: box.width; height: box.height; radius: box.radius
                color: "transparent"; border.width: 2; border.color: index ? root.opp : root.glow
                opacity: 0.8
            }
        }
        Rectangle { id: haloSrc; x: box.x; y: box.y; width: box.width; height: box.height; radius: box.radius; color: root.glow; visible: false; layer.enabled: true }
        MultiEffect {
            source: haloSrc; x: haloSrc.x; y: haloSrc.y; width: haloSrc.width; height: haloSrc.height
            blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 1.6; autoPaddingEnabled: true
            opacity: 0.22 * root.intro
        }

        // ombre portée : la carte flotte au-dessus du bureau
        RectangularShadow {
            x: box.x; y: box.y + 18; width: box.width; height: box.height; radius: box.radius
            blur: 56; spread: -6; color: ColorUtils.applyAlpha("#000000", 0.7 * root.intro)
        }

        // ── la carte ──────────────────────────────────────────────────────────
        ClippingRectangle {
            id: box
            x: root.cardX + (root.fullW - root.mw) / 2
            y: root.cardY + (root.fullH - root.mh) / 2
            width: root.mw; height: root.mh
            radius: Math.min(root.rad(root.fullH), height / 2)
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96 * root.bgA)
            // contour fixe si les bordures animées sont coupées (Réglages › Thème)
            border.width: Appearance.animationsEnabled ? 0 : 2
            border.color: ColorUtils.applyAlpha(root.glow, 0.85)
            MouseArea { anchors.fill: parent }
            Rectangle {
                anchors.fill: parent
                opacity: root.bgA
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07) }
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha("#000000", 0.18) }
                }
            }
            Rectangle { x: box.radius; width: parent.width - box.radius * 2; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.16 * root.bgA) }

            Item {
                x: (root.mw - root.fullW) / 2; y: (root.mh - root.fullH) / 2
                width: root.fullW; height: root.fullH
                opacity: root.intro
                transform: Translate { y: (1 - root.intro) * 12 }

                // ── bandeau (comme rofi) : le fond d'écran, la recherche, les onglets ──
                ClippingRectangle {
                    id: head
                    x: 18; y: 18; width: parent.width - 36; height: 96
                    radius: root.rad(height)
                    color: Appearance.colors.color0
                    Image {
                        anchors.fill: parent
                        source: WallpaperState.videoMode ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
                              : WallpaperState.currentWall ? "file://" + WallpaperState.currentWall : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                        sourceSize.width: 1400
                        opacity: 0.85
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55) }
                            GradientStop { position: 0.5; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.15) }
                            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55) }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.55; color: "transparent" }
                            GradientStop { position: 1.0; color: ColorUtils.applyAlpha("#000000", 0.45) }
                        }
                    }
                    Rectangle { anchors.fill: parent; radius: head.radius; color: "transparent"; border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }
                    RectangularShadow {
                        x: pill.x; y: pill.y + 6; width: pill.width; height: pill.height; radius: pill.radius
                        blur: 22; spread: -2; color: ColorUtils.applyAlpha(root.glow, 0.45)
                    }
                    // recherche : pastille à la couleur du menu
                    Rectangle {
                        id: pill
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: (root.tabs.length ? parent.width * 0.5 : parent.width - 70) - 12; height: 48; radius: root.rad(height)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Qt.lighter(root.glow, 1.18), 0.95) }
                            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Qt.darker(root.glow, 1.12), 0.92) }
                        }
                        border.width: 1; border.color: ColorUtils.applyAlpha("#ffffff", 0.18)
                        Row {
                            id: pLead
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.req.icon || "󰍉"
                                   font.family: Appearance.font.family; font.pixelSize: 18; color: Appearance.textOn(root.glow) }
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: !!(root.req.title || root.req.prompt)
                                   text: (root.req.title || root.req.prompt) + "  ›"; font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold
                                   color: Appearance.textOn(root.glow) }
                        }
                        TextInput {
                            id: field
                            anchors { left: pLead.right; leftMargin: 12; right: cnt.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            visible: root.hasSearch
                            font.family: Appearance.font.family; font.pixelSize: 16
                            color: Appearance.textOn(root.glow); selectionColor: Appearance.colors.bg; selectedTextColor: Appearance.colors.fg
                            echoMode: root.req.password ? TextInput.Password : TextInput.Normal
                            clip: true
                            onTextChanged: root.query = text
                            Keys.onPressed: (e) => root.key(e)
                            Text { visible: field.text === ""; text: root.req.placeholder || (root.tpl === "input" ? "Écrire…" : "Search")
                                   font: field.font; color: ColorUtils.applyAlpha(Appearance.textOn(root.glow), 0.6) }
                        }
                        Text {
                            id: cnt
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            visible: root.source.length > 0 && root.filtering && !root.req.live
                            text: root.items.length !== root.source.length ? root.items.length + " / " + root.source.length : root.source.length
                            font.family: Appearance.font.family; font.pixelSize: 12; color: ColorUtils.applyAlpha(Appearance.textOn(root.glow), 0.75)
                        }
                    }
                    // onglets (TABS du script) : un autre menu, sans refermer la carte
                    Row {
                        anchors { left: pill.right; leftMargin: 10; right: closeB.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Repeater {
                            model: root.tabs
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool on: modelData.run === root.req.tab
                                width: (parent.width - 6 * (root.tabs.length - 1)) / root.tabs.length; height: 48; radius: root.rad(height)
                                color: on ? ColorUtils.applyAlpha(root.glow, 0.88) : tMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.bg, 0.55) : "transparent"
                                Behavior on color { ColorAnimation { duration: Appearance.dur(180) } }
                                Text { anchors.centerIn: parent; width: parent.width - 16; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                       text: parent.modelData.icon + "  " + parent.modelData.label
                                       font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                                       color: parent.on ? Appearance.textOn(root.glow) : Appearance.colors.fg }
                                MouseArea { id: tMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.switchTab(parent.index) }
                            }
                        }
                    }
                    Rectangle {
                        id: closeB
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34; radius: 17
                        color: xMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.bg, 0.8) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg }
                        MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.finish(1, "") }
                    }
                }
                // message (MESSAGE / -mesg) : pastille à la longueur du texte + une petite marge, centrée
                Rectangle {
                    id: mesg
                    visible: root.hasMesg
                    width: Math.min(parent.width - 36, mTxt.implicitWidth + 56)
                    x: (parent.width - width) / 2; y: root.headH; height: 46; radius: root.rad(height)
                    Behavior on width { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
                    color: ColorUtils.applyAlpha(root.glow, 0.85)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(300) } }
                    Text {
                        id: mTxt
                        anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 30); horizontalAlignment: Text.AlignHCenter
                        text: (root.req.mesg || "").replace(/\*\*/g, "")
                        elide: Text.ElideRight; textFormat: Text.PlainText
                        font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold
                        color: Appearance.textOn(root.glow)
                    }
                }

                // ── le template ──
                Loader {
                    id: view
                    x: 26; y: root.headH + (root.hasMesg ? 60 : 0)
                    width: parent.width - 52; height: root.contentH
                }

                // ── pied : élément choisi, position, raccourcis, bouton ──
                Rectangle {
                    x: 26; width: parent.width - 52; height: 1
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 68
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.14) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Item {
                    x: 26; width: parent.width - 52; height: 38
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                    Column {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - footR.width - 20
                        Text { width: parent.width; elide: Text.ElideMiddle
                               text: root.curItem && !root.isHead(root.curItem) ? root.curItem.t.split("\t")[0] : (root.tpl === "input" ? root.query : "")
                               font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                        Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""
                               text: root.curItem ? (root.curItem.sub || root.curItem.t.split("\t").slice(1).join("  ·  ")) : ""
                               font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                    }
                    Row {
                        id: footR
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 16
                        Text { anchors.verticalCenter: parent.verticalCenter
                               visible: root.items.length > 1 && !!root.curItem
                               text: (root.cur + 1) + " / " + root.items.length
                               font.family: "JetBrains Mono"; font.pixelSize: 12; color: Appearance.colors.dim }
                        Text { anchors.verticalCenter: parent.verticalCenter
                               text: (view.item && view.item.hints ? view.item.hints : "↑↓ choisir") + "  ·  Échap"
                               font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
                        Rectangle {
                            visible: root.tpl !== "info" && root.tpl !== "confirm"
                            width: apT.implicitWidth + 30; height: 38; radius: root.rad(height)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.lighter(root.glow, apMa.containsMouse ? 1.3 : 1.15) }
                                GradientStop { position: 1.0; color: Qt.darker(root.glow, 1.1) }
                            }
                            border.width: 1; border.color: ColorUtils.applyAlpha("#ffffff", 0.2)
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.glow; shadowBlur: 0.8; shadowOpacity: 0.55
                                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 3; autoPaddingEnabled: true }
                            Text { id: apT; anchors.centerIn: parent; text: root.req.action || (root.tpl === "apps" ? "󰐊  Lancer" : "󰄬  Valider")
                                   font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold; color: Appearance.textOn(root.glow) }
                            MouseArea { id: apMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.accept(false) }
                        }
                    }
                }
            }
        }

        // contour dégradé animé, comme les autres panneaux ([theme] animated_borders, border_speed)
        GradientBorder {
            x: box.x; y: box.y; width: box.width; height: box.height
            radius: box.radius; borderWidth: 2
            visible: root.shown && Appearance.animationsEnabled
        }

        Rectangle {   // tranche du glitch
            visible: root.gl > 0.05
            x: box.x - 12 * root.gl; width: box.width
            y: { root.tick; return box.y + Math.random() * box.height }
            height: { root.tick; return 4 + Math.random() * 18 }
            color: ColorUtils.applyAlpha(root.glow, 0.35)
        }
        // Jarvis : contour qui se trace + équerres aux coins
        Shape {
            id: jvShape
            visible: root.draw < 1
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4
            readonly property real per: 2 * (box.width + box.height)
            ShapePath {
                strokeColor: root.glow; strokeWidth: 2; fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [Math.max(0.01, jvShape.per * root.draw / 2), jvShape.per]
                PathRectangle { x: box.x; y: box.y; width: box.width; height: box.height; radius: box.radius }
            }
        }
        Repeater {
            model: root.style === "jarvis" ? 4 : 0
            Item {
                required property int index
                readonly property bool r: index % 2
                readonly property bool b: index >= 2
                readonly property real len: 34 * root.draw
                x: r ? box.x + box.width + 8 - len : box.x - 8
                y: b ? box.y + box.height + 8 - len : box.y - 8
                width: len; height: len
                Rectangle { width: parent.width; height: 2; y: parent.b ? parent.height - 2 : 0; color: root.glow }
                Rectangle { width: 2; height: parent.height; x: parent.r ? parent.width - 2 : 0; color: root.glow }
            }
        }
        // Jarvis : ligne de balayage
        Item {
            visible: root.scan >= 0 && root.scan <= 1
            x: box.x; width: box.width
            y: box.y + root.scan * box.height - 60; height: 62
            clip: true
            Rectangle { anchors.fill: parent; gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: ColorUtils.applyAlpha(root.glow, 0.28) } } }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: root.glow }
        }
        // Matrix : flash de l'allumage
        Rectangle { x: box.x; y: box.y; width: box.width; height: box.height; radius: box.radius; color: "white"; opacity: root.flash }
    }

    // ── clavier ───────────────────────────────────────────────────────────
    readonly property var keyNames: ({ [Qt.Key_Delete]: "delete", [Qt.Key_Backspace]: "backspace", [Qt.Key_Return]: "return", [Qt.Key_Enter]: "return",
                                       [Qt.Key_Tab]: "tab", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                                       [Qt.Key_Home]: "home", [Qt.Key_End]: "end", [Qt.Key_Space]: "space" })
    function combo(e) {
        const n = keyNames[e.key] || (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F12 ? "f" + (e.key - Qt.Key_F1 + 1) : (e.text || "").toLowerCase())
        if (!n) return ""
        return ((e.modifiers & Qt.ControlModifier) ? "control-" : "") + ((e.modifiers & Qt.AltModifier) ? "alt-" : "")
             + ((e.modifiers & Qt.ShiftModifier) && n.length > 1 ? "shift-" : "") + ((e.modifiers & Qt.MetaModifier) ? "super-" : "") + n
    }
    function key(e) {
        const keys = req.keys || {}, c = combo(e)
        for (const k in keys)
            if (k.toLowerCase().replace(/\+/g, "-").replace("ctrl-", "control-") === c) {
                const it = items[cur]
                finish(keys[k], it ? (it.id || it.t) : query); e.accepted = true; return
            }
        const cols = view.item && view.item.cols ? view.item.cols : 1
        const rows = view.item && view.item.rows ? view.item.rows : 8
        const across = cols > 1 || (view.item && view.item.horizontal)
        const ti = tabs.findIndex(x => x.run === req.tab)
        if (tabs.length && ((e.key === Qt.Key_Tab && (e.modifiers & Qt.ControlModifier)) || (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Right))) { switchTab((ti + 1) % tabs.length); e.accepted = true; return }
        if (tabs.length && ((e.key === Qt.Key_Backtab && (e.modifiers & Qt.ControlModifier)) || (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Left))) { switchTab((ti + tabs.length - 1) % tabs.length); e.accepted = true; return }
        if ((e.modifiers & Qt.ShiftModifier) && (e.key === Qt.Key_Up || e.key === Qt.Key_Down) && view.item && view.item.scrollPreview) {
            view.item.scrollPreview(e.key === Qt.Key_Down ? 1 : -1); e.accepted = true; return
        }
        if (e.key === Qt.Key_Escape) finish(1, "")
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) accept(e.modifiers & Qt.ShiftModifier)
        else if (e.key === Qt.Key_Down) step(cols)
        else if (e.key === Qt.Key_Up) step(-cols)
        else if (e.key === Qt.Key_Tab) step(e.modifiers & Qt.ShiftModifier ? -1 : 1)
        else if (across && e.key === Qt.Key_Right) step(1)
        else if (across && e.key === Qt.Key_Left) step(-1)
        else if (e.key === Qt.Key_PageDown) step(cols * rows)
        else if (e.key === Qt.Key_PageUp) step(-cols * rows)
        else return
        e.accepted = true
    }
}
