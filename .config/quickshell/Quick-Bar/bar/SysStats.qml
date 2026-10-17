pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.core
import qs.core.functions
import qs.components.stats
import qs.services

// SysStats — CPU · RAM · températures (CPU, GPU, NVMe) · disque dans la barre.
//   survol      → carte détaillée (courbe, cœurs, capteurs, processus, place libre)
//   clic        → btop / sensors / amdgpu_top / ncdu
//   clic droit  → actions (profil d'énergie, seuils d'alerte, outils GPU, nettoyage…)
//   clic milieu → format (RAM Go ↔ %, disque utilisé ↔ libre)
// Données : scripts/system/sysstats.py (démon, une ligne JSON toutes les 2 s ;
// processus et place récupérable seulement pendant qu'une carte est ouverte).
// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 2; columnSpacing: 2

    // ── Données : services/SysData.qml (démon partagé avec les pages System) ──
    readonly property var    d:        SysData.d
    readonly property var    hist:     SysData.hist
    readonly property var    prefs:    SysData.prefs
    function setPref(k, v) { SysData.setPref(k, v) }
    readonly property int    cpu:      SysData.cpu
    readonly property real   memTotal: SysData.memTotal
    readonly property real   memUsed:  SysData.memUsed
    readonly property int    memPct:   SysData.memPct
    readonly property var    rootDisk: SysData.rootDisk
    readonly property int    diskPct:  SysData.diskPct
    readonly property real   cpuT:     SysData.cpuT
    readonly property real   gpuT:     SysData.gpuT
    readonly property real   nvmeT:    SysData.nvmeT
    readonly property int    cpuAlert:  SysData.cpuAlert
    readonly property int    gpuAlert:  SysData.gpuAlert
    readonly property int    nvmeAlert: SysData.nvmeAlert
    readonly property string profile:  SysData.profile
    function gb(b) { return SysData.gb(b) }
    function size(b) { return SysData.size(b) }
    function mbs(b) { return SysData.mbs(b) }
    function mountName(m) { return SysData.mountName(m) }
    function lvl(v, warn, crit, base) { return SysData.lvl(v, warn, crit, base) }
    readonly property color cpuCol:   SysData.cpuCol
    readonly property color ramCol:   SysData.ramCol
    readonly property color tcpuCol:  SysData.tcpuCol
    readonly property color tgpuCol:  SysData.tgpuCol
    readonly property color tnvmeCol: SysData.tnvmeCol
    readonly property color diskCol:  SysData.diskCol
    // Détail (processus, place récupérable) seulement quand une carte ou un menu est ouvert
    readonly property bool wantDetail: cardChip !== null || menuChip !== null
    onWantDetailChanged: SysData.want("bar", wantDetail)

    // ── Actions ───────────────────────────────────────────────────────────
    function run(cmd) { SysData.run(cmd) }
    function notify(t, b) { SysData.notify(t, b) }
    function leftAction(kind) { SysData.open(kind) }
    function middleAction(kind) {
        if (kind === "ram") setPref("ramPct", !prefs.ramPct)
        else if (kind === "disk") setPref("diskFree", !prefs.diskFree)
    }
    function wheelAction(kind, up) {}

    // ── Puce de la barre ──────────────────────────────────────────────────
    component StatChip: Item {
        id: chip
        property string kind: ""
        property string icon: ""
        property string label: ""
        property int    percent: -1
        property color  col: Appearance.colors.fg
        property bool   alert: false

        implicitWidth:  Appearance.bar.vertical ? Appearance.bar.thickness - 6 : chipRow.implicitWidth + 14
        implicitHeight: Appearance.bar.vertical ? chipRow.implicitHeight + 10 : Appearance.bar.height - 4

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: ma.containsMouse || root.cardChip === chip || root.menuChip === chip
                ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
        }

        // icône à gauche de la valeur, ou au-dessus en barre verticale
        GridLayout {
            id: chipRow
            anchors.centerIn: parent
            flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 3; columnSpacing: 5

            Text {
                id: ico
                Layout.alignment: Qt.AlignCenter
                text: chip.icon
                font.family: Appearance.font.family
                font.pixelSize: Appearance.bar.icon
                color: chip.col
                opacity: ma.containsMouse ? 1.0 : 0.75
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(120) } }
                Behavior on color   { ColorAnimation  { duration: 200 } }
                // Au-delà du seuil : l'icône pulse
                SequentialAnimation on scale {
                    running: chip.alert
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) ico.scale = 1
                    NumberAnimation { to: 1.22; duration: 520; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 520; easing.type: Easing.InOutSine }
                }
            }

            // valeur centrée sur la ligne de l'icône ; la jauge se pose juste dessous sans compter
            // dans la hauteur (sinon le texte remonte au-dessus du centre de la barre)
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: lbl.implicitWidth
                implicitHeight: lbl.implicitHeight
                Text {
                    id: lbl
                    text: chip.label
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.bar.text
                    color: chip.col
                    opacity: ma.containsMouse ? 1.0 : 0.80
                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(120) } }
                    Behavior on color   { ColorAnimation  { duration: Appearance.dur(200) } }
                }
                Item {
                    visible: chip.percent >= 0
                    anchors.horizontalCenter: lbl.horizontalCenter
                    y: lbl.height - 1
                    // largeur du texte (pas de la puce : sinon boucle de calcul quand la barre grandit)
                    width:   Appearance.bar.vertical ? chip.width - 14 : lbl.implicitWidth
                    height:  2
                    Rectangle { anchors.fill: parent; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.color15, 0.10) }
                    Rectangle {
                        width:  Math.max(2, parent.width * Math.min(100, chip.percent) / 100)
                        height: parent.height; radius: 1
                        color:  chip.col; opacity: 0.75
                        Behavior on width { NumberAnimation { duration: Appearance.dur(400); easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: Appearance.dur(200) } }
                    }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onContainsMouseChanged: root.chipHover(chip, containsMouse)
            onClicked: (e) => {
                if (e.button === Qt.RightButton) root.openMenu(chip)
                else if (e.button === Qt.MiddleButton) root.middleAction(chip.kind)
                else { root.cardChip = null; root.leftAction(chip.kind) }
            }
            onWheel: (w) => root.wheelAction(chip.kind, w.angleDelta.y > 0)
        }
    }

    // ── Puces affichées : [bar] stats (ordre + masquées absentes) — Réglages › Barre › Modules ──
    readonly property var allStats: ["cpu", "ram", "tcpu", "tgpu", "tnvme", "disk"]
    readonly property var statKeys: {
        const v = Config.get("bar.stats", allStats)
        const k = (Array.isArray(v) ? v : allStats).filter(x => allStats.indexOf(x) >= 0)
        return k.length ? k : allStats
    }
    readonly property var chipIcon: ({ cpu: "󰍛", ram: "󰾆", tcpu: "󰔏", tgpu: "󰢮", tnvme: "󰆼", disk: "󰋊" })
    function isTemp(k) { return k === "tcpu" || k === "tgpu" || k === "tnvme" }
    function chipLabel(k) {
        if (k === "cpu")   return cpu + "%"
        if (k === "ram")   return prefs.ramPct ? memPct + "%" : (memUsed / 1073741824).toFixed(1) + "G"
        if (k === "tcpu")  return Math.round(cpuT) + "°"
        if (k === "tgpu")  return Math.round(gpuT) + "°"
        if (k === "tnvme") return Math.round(nvmeT) + "°"
        return prefs.diskFree && rootDisk ? Math.round(rootDisk.avail / 1073741824) + "G" : diskPct + "%"
    }
    function chipPct(k) {
        if (k === "cpu")   return cpu
        if (k === "ram")   return memPct
        if (k === "tcpu")  return Math.round((cpuT - 30) / 70 * 100)
        if (k === "tgpu")  return Math.round((gpuT - 30) / 80 * 100)
        if (k === "tnvme") return Math.round((nvmeT - 25) / 60 * 100)
        return diskPct
    }
    function chipCol(k) { return ({ cpu: cpuCol, ram: ramCol, tcpu: tcpuCol, tgpu: tgpuCol, tnvme: tnvmeCol, disk: diskCol })[k] }
    function chipAlert(k) {
        if (k === "cpu")   return cpu > 85
        if (k === "ram")   return memPct > 85
        if (k === "tcpu")  return cpuT > cpuAlert
        if (k === "tgpu")  return gpuT > gpuAlert
        if (k === "tnvme") return nvmeT > nvmeAlert
        return diskPct > 90
    }

    Repeater {
        model: root.statKeys
        delegate: GridLayout {
            id: slot
            required property string modelData
            required property int index
            flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2; columnSpacing: 2
            // trait entre les puces, sauf entre deux températures (elles restent groupées)
            Rectangle {
                visible: slot.index > 0 && !(root.isTemp(slot.modelData) && root.isTemp(root.statKeys[slot.index - 1]))
                Layout.alignment: Qt.AlignCenter
                implicitWidth: Appearance.bar.vertical ? 14 : 1; implicitHeight: Appearance.bar.vertical ? 1 : 12
                radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            }
            StatChip {
                Layout.alignment: Qt.AlignCenter
                kind: slot.modelData; icon: root.chipIcon[slot.modelData]
                label: root.chipLabel(slot.modelData); percent: root.chipPct(slot.modelData)
                col: root.chipCol(slot.modelData); alert: root.chipAlert(slot.modelData)
            }
        }
    }

    // ══ Carte au survol ═══════════════════════════════════════════════════
    property Item hoverChip: null        // puce sous le curseur
    property Item cardChip: null         // puce dont la carte est affichée
    property Item lastCardChip: null     // garde l'ancrage pendant le fondu de fermeture
    onCardChipChanged: if (cardChip) lastCardChip = cardChip
    Timer { id: showT; interval: 260; onTriggered: if (root.hoverChip && !root.menuChip) root.cardChip = root.hoverChip }
    Timer { id: hideT; interval: 220; onTriggered: if (!root.hoverChip && !cardHov.hovered) root.cardChip = null }
    function chipHover(chip, on) {
        if (on) {
            hoverChip = chip; hideT.stop()
            if (cardChip) cardChip = chip          // déjà ouverte : bascule direct sur la voisine
            else showT.restart()
        } else {
            if (hoverChip === chip) hoverChip = null
            showT.stop(); hideT.restart()
        }
    }

    // Cartes : components/stats/ (partagées avec les pages System)
    Component { id: cpuCard; CpuCard {} }
    Component { id: ramCard; RamCard {} }
    Component { id: tcpuCard; CpuTempCard {} }
    Component { id: tgpuCard; GpuCard {} }
    Component { id: tnvmeCard; NvmeCard {} }
    Component { id: diskCard; DiskCard {} }

    PopupWindow {
        id: cardWin
        readonly property bool shown: root.cardChip !== null
        anchor.item: root.lastCardChip ?? root
        anchor.rect.width:  root.lastCardChip ? root.lastCardChip.width : 0
        // La fenêtre commence juste sous la puce (au-dessus si la barre est en bas) : la goutte en sort
        anchor.rect.height: root.lastCardChip && !Appearance.bar.atBottom ? root.lastCardChip.height : 0
        // barre verticale : la carte s'ouvre à côté de la puce (à droite d'une barre à gauche, et inversement)
        anchor.edges:   Appearance.bar.position === "left" ? Edges.Right : Appearance.bar.position === "right" ? Edges.Left
                      : Appearance.bar.atBottom ? Edges.Top : Edges.Bottom
        anchor.gravity: Appearance.bar.position === "left" ? Edges.Right : Appearance.bar.position === "right" ? Edges.Left
                      : Appearance.bar.atBottom ? Edges.Top : Edges.Bottom
        implicitWidth:  400
        implicitHeight: cardBox.fullH + cardBox.restY + 8
        visible: shown || cardBox.opacity > 0.01
        color: "transparent"

        // Ouverture en trois temps :
        //   1. une goutte (cercle) sort de la puce et descend
        //   2. elle s'étire à l'horizontale en pilule jusqu'à la largeur de la carte
        //   3. elle se déroule vers le bas jusqu'à sa hauteur, puis le contenu apparaît
        // Fermeture : simple fondu, sur place.
        ClippingRectangle {
            id: cardBox
            readonly property real fullW: cardWin.width - 12
            readonly property real fullH: cardLoader.implicitHeight + 32
            readonly property real restY: 12
            readonly property real dot: 26
            property real w: fullW
            property real h: fullH
            property real content: 1
            property real off: 0                 // décalage de la goutte vers la puce
            x: (cardWin.width - w) / 2
            // collée au côté de la puce : en haut sous une barre en haut, en bas au-dessus d'une barre en bas
            y: Appearance.bar.vertical ? restY : Appearance.bar.atBottom ? cardWin.height - restY - h + off : restY - off
            width: w; height: h
            radius: Math.min(16, Math.min(w, h) / 2)
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.color15, 0.22)
            opacity: cardWin.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Appearance.dur(160) } }
            // Changement de puce carte ouverte : la hauteur suit en douceur
            Behavior on h { enabled: !cardEnter.running; NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }

            Connections {
                target: cardWin
                function onShownChanged() { if (cardWin.shown && cardBox.opacity < 0.05) cardEnter.restart() }
            }
            SequentialAnimation {
                id: cardEnter
                ScriptAction { script: { cardBox.w = cardBox.dot; cardBox.h = cardBox.dot; cardBox.content = 0 } }
                // 1. la goutte sort de la puce (descend, ou monte si la barre est en bas)
                NumberAnimation { target: cardBox; property: "off"; from: cardBox.dot + cardBox.restY; to: 0; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                // 2. elle s'étire à l'horizontale
                NumberAnimation { target: cardBox; property: "w"; to: cardBox.fullW; duration: Appearance.dur(400); easing.type: Easing.OutCubic }
                // 3. elle se déroule vers le bas, le contenu apparaît en fin de course
                ParallelAnimation {
                    NumberAnimation { target: cardBox; property: "h"; to: cardBox.fullH; duration: Appearance.dur(540); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    SequentialAnimation {
                        PauseAnimation { duration: Appearance.dur(220) }
                        NumberAnimation { target: cardBox; property: "content"; to: 1; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                    }
                }
                // retour aux liaisons : la carte suit ensuite la taille de son contenu
                ScriptAction { script: { cardBox.w = Qt.binding(() => cardBox.fullW); cardBox.h = Qt.binding(() => cardBox.fullH) } }
            }
            HoverHandler { id: cardHov; onHoveredChanged: if (!hovered) hideT.restart() }

            Loader {
                id: cardLoader
                x: 16 - (cardBox.fullW - cardBox.w) / 2
                y: 16 + (1 - cardBox.content) * 8
                width: cardBox.fullW - 32
                opacity: cardBox.content
                readonly property string kind: root.lastCardChip ? root.lastCardChip.kind : ""
                sourceComponent: kind === "cpu" ? cpuCard : kind === "ram" ? ramCard : kind === "tcpu" ? tcpuCard : kind === "tgpu" ? tgpuCard : kind === "tnvme" ? tnvmeCard : kind === "disk" ? diskCard : null
            }
        }
    }

    // ══ Menu du clic droit ════════════════════════════════════════════════
    property Item menuChip: null
    property Item lastMenuChip: null     // garde l'ancrage pendant le fondu de fermeture
    onMenuChipChanged: if (menuChip) lastMenuChip = menuChip
    property string armed: ""            // action dangereuse en attente de confirmation
    function openMenu(chip) { cardChip = null; showT.stop(); armed = ""; menuChip = chip; menuLeave.stop() }
    function closeMenu() { menuChip = null; armed = ""; menuLeave.stop() }
    // Le menu se ferme seul quand le curseur n'est plus ni sur lui ni sur sa puce
    readonly property bool menuHovered: menuHov.hovered || (hoverChip !== null && hoverChip === menuChip)
    onMenuHoveredChanged: if (menuChip) { if (menuHovered) menuLeave.stop(); else menuLeave.restart() }
    Timer { id: menuLeave; interval: 700; onTriggered: root.closeMenu() }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = "" }

    function topName(list) { return list && list.length ? list.find(p => p.name !== "quickshell") : null }
    // Menu clic droit = actions de la stat + gestion des puces
    function menuItems(kind) {
        const extra = [{ type: "sep" },
            { type: "item", icon: "󰈉", text: "Masquer cette stat", act: () => hideStat(kind) },
            { type: "item", icon: "󰒓", text: "Gérer les stats…", act: () => { Popups.closeAll(); Popups.settingsHint = "stats"; Popups.settingsPage = "bar"; Popups.settingsOpen = true } }]
        return _menuItems(kind).concat(statKeys.length > 1 ? extra : extra.filter((x, i) => i !== 1))
    }
    function hideStat(kind) {
        const k = statKeys.filter(x => x !== kind)
        if (k.length) Config.set("bar.stats", k)
    }
    function _menuItems(kind) {
        const it = (icon, text, act, extra) => Object.assign({ type: "item", icon: icon, text: text, act: act }, extra || {})
        const sep = { type: "sep" }
        const title = t => ({ type: "title", text: t })
        const seg = (opts, cur, set) => ({ type: "seg", opts: opts, cur: cur, set: set })
        if (kind === "cpu") {
            const top = topName(d && d.topCpu)
            const l = [it("󰍛", "Ouvrir btop", () => leftAction("cpu"), { hint: "clic" }), sep, title("Profil d'énergie"),
                       seg([["performance", "Perf."], ["balanced", "Équilibré"], ["power-saver", "Économie"]], profile,
                           v => { SysData.profileSet = v; run(["powerprofilesctl", "set", v]) }), sep]
            if (top) l.push(it("󰆴", "Arrêter « " + top.name + " » (" + top.pct.toFixed(0) + " %)", () => run(["pkill", "-x", top.name]), { danger: true }))
            l.push(it("󰅍", "Copier le résumé", () => run(["wl-copy", "CPU " + cpu + " % · " + (d ? d.freq + " GHz · charge " + d.load : "") + " · " + Math.round(cpuT) + " °C"])))
            return l
        }
        if (kind === "ram") {
            const top = topName(d && d.topMem)
            const l = [it("󰾆", "Ouvrir btop", () => leftAction("ram"), { hint: "clic" }),
                       it("󰑓", "Relancer Quick-Bar", () => run(["bash", "-c",
                           "quickshell kill -p \"$1\"; sleep 1; MALLOC_MMAP_THRESHOLD_=131072 setsid -f quickshell -p \"$1\" >/dev/null 2>&1",
                           "_", Quickshell.shellDir + "/shell.qml"])),
                       sep, title("Affichage dans la barre"),
                       seg([[false, "Go"], [true, "%"]], !!prefs.ramPct, v => setPref("ramPct", v)), sep]
            if (top) l.push(it("󰆴", "Fermer « " + top.name + " » (" + gb(top.bytes) + ")", () => run(["pkill", "-x", top.name]), { danger: true }))
            return l
        }
        if (kind === "tcpu") return [
            it("󰔏", "Ouvrir sensors", () => leftAction("tcpu"), { hint: "clic" }), sep,
            title("Alerte au-delà de"),
            seg([[75, "75°"], [82, "82°"], [90, "90°"]], cpuAlert, v => setPref("tempAlert", v)),
            title("Profil d'énergie"),
            seg([["performance", "Perf."], ["balanced", "Équilibré"], ["power-saver", "Économie"]], profile,
                v => { SysData.profileSet = v; run(["powerprofilesctl", "set", v]) })
        ]
        if (kind === "tgpu") return [
            it("󰢮", "Ouvrir amdgpu_top", () => leftAction("tgpu"), { hint: "clic" }),
            it("󰍹", "Ouvrir nvtop", () => run(Config.term("GPU", ["nvtop"]))),
            it("󰒓", "Réglages GPU (LACT)", () => run(["lact", "gui"]), { hint: "ventilo, fréquences" }), sep,
            title("Alerte junction au-delà de"),
            seg([[90, "90°"], [95, "95°"], [100, "100°"]], gpuAlert, v => setPref("gpuAlert", v))
        ]
        if (kind === "tnvme") return [
            it("󰆼", "Capteurs NVMe", () => leftAction("tnvme"), { hint: "clic" }),
            it("󰓙", "Santé SMART des disques", () => run(Config.term("SMART", ["sh", "-c",
                "for d in /dev/nvme?n1; do echo \"== $d\"; sudo smartctl -H -A \"$d\" | grep -E 'result|Temperature|Percentage Used|Available Spare|Media|Power On'; done; echo; read -p 'Entrée pour fermer'"])),
                { hint: "mot de passe" }), sep,
            title("Alerte au-delà de"),
            seg([[65, "65°"], [70, "70°"], [75, "75°"]], nvmeAlert, v => setPref("nvmeAlert", v))
        ]
        if (kind === "disk") {
            const r = d && d.reclaim ? d.reclaim : {}
            return [
                it("󰋊", "Analyser / avec ncdu", () => leftAction("disk"), { hint: "clic" }), sep, title("Affichage dans la barre"),
                seg([[false, "Utilisé %"], [true, "Libre"]], !!prefs.diskFree, v => setPref("diskFree", v)), sep,
                it("󰩺", "Vider la corbeille" + (r.trash !== undefined ? " · " + size(r.trash) : ""),
                   () => { run(["gio", "trash", "--empty"]); notify("Corbeille vidée") }, { danger: true }),
                it("󰏗", "Nettoyer le cache pacman" + (r.pacman !== undefined ? " · " + size(r.pacman) : ""),
                   () => run(["bash", "-c", "pkexec bash -c 'paccache -rk1 && paccache -ruk0' && notify-send -a Quick-Bar 'Cache pacman nettoyé' 'Dernière version de chaque paquet gardée'"]),
                   { hint: "garde 1 version" })
            ]
        }
        return []
    }

    PopupWindow {
        id: menuWin
        readonly property bool shown: root.menuChip !== null
        anchor.item: root.lastMenuChip ?? root
        anchor.rect.width:  root.lastMenuChip ? root.lastMenuChip.width : 0
        anchor.rect.y:      Appearance.bar.atBottom ? -8 : 0
        anchor.rect.height: Appearance.bar.atBottom ? 0 : (root.lastMenuChip ? root.lastMenuChip.height : 0) + 8
        anchor.edges:   Appearance.bar.position === "left" ? Edges.Right : Appearance.bar.position === "right" ? Edges.Left
                      : Appearance.bar.atBottom ? Edges.Top : Edges.Bottom
        anchor.gravity: Appearance.bar.position === "left" ? Edges.Right : Appearance.bar.position === "right" ? Edges.Left
                      : Appearance.bar.atBottom ? Edges.Top : Edges.Bottom
        implicitWidth:  menuBox.implicitWidth + 12
        implicitHeight: menuBox.implicitHeight + 12
        visible: shown || menuBox.opacity > 0.01
        color: "transparent"

        // Clic ailleurs = fermer (la grab est armée une fois la fenêtre affichée)
        HyprlandFocusGrab {
            id: menuGrab
            windows: [menuWin]
            onCleared: root.closeMenu()
        }
        onShownChanged: if (shown) Qt.callLater(() => menuGrab.active = true); else menuGrab.active = false

        Rectangle {
            id: menuBox
            x: 6
            implicitWidth: Math.max(270, menuCol.implicitWidth + 12)
            implicitHeight: menuCol.implicitHeight + 12
            radius: 14
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.97)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.color15, 0.25)
            // Entrée élastique depuis le haut ; sortie : simple fondu, sans bouger
            opacity: menuWin.shown ? 1 : 0
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: Appearance.dur(140) } }
            Connections {
                target: menuWin
                function onShownChanged() { if (menuWin.shown) menuEnter.restart() }
            }
            NumberAnimation { id: menuEnter; target: menuBox; property: "scale"; from: 0.9; to: 1; duration: Appearance.dur(220); easing.type: Easing.OutBack; easing.overshoot: 2 }
            HoverHandler { id: menuHov }

            ColumnLayout {
                id: menuCol
                x: 6; y: 6
                width: parent.width - 12
                spacing: 2

                Repeater {
                    model: root.lastMenuChip ? root.menuItems(root.lastMenuChip.kind) : []
                    delegate: Loader {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        sourceComponent: modelData.type === "sep" ? sepC : modelData.type === "title" ? titleC
                                       : modelData.type === "seg" ? segC : itemC

                        Component {
                            id: sepC
                            Rectangle { implicitHeight: 9; color: "transparent"
                                Rectangle { anchors.centerIn: parent; width: parent.width - 12; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.10) } }
                        }
                        Component {
                            id: titleC
                            Text { text: row.modelData.text; leftPadding: 12; topPadding: 6; bottomPadding: 2
                                   font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.5
                                   font.capitalization: Font.AllUppercase; color: Appearance.colors.dim }
                        }
                        Component {
                            id: segC
                            Item {
                                id: sg
                                implicitHeight: 38
                                readonly property int sel: row.modelData.opts.findIndex(o => o[0] === row.modelData.cur)
                                // pastille de sélection qui glisse
                                Rectangle {
                                    readonly property Item tgt: sg.sel >= 0 && segRep.count > sg.sel ? segRep.itemAt(sg.sel) : null
                                    visible: tgt !== null
                                    x: tgt ? segRow.x + tgt.x : 0; y: 4; width: tgt ? tgt.width : 0; height: 30; radius: 8
                                    color: Appearance.colors.fg
                                    Behavior on x { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                                }
                                Row {
                                    id: segRow
                                    x: 6; y: 4; spacing: 4
                                    Repeater {
                                        id: segRep
                                        model: row.modelData.opts
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: (sg.width - 12 - 4 * (row.modelData.opts.length - 1)) / row.modelData.opts.length
                                            height: 30; radius: 8
                                            color: index === sg.sel ? "transparent" : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData[1]
                                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.DemiBold
                                                color: parent.index === sg.sel ? Appearance.colors.bg : Appearance.colors.fg
                                                Behavior on color { ColorAnimation { duration: Appearance.dur(180) } }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.modelData.set(parent.modelData[0]) }
                                        }
                                    }
                                }
                            }
                        }
                        Component {
                            id: itemC
                            Rectangle {
                                id: mi
                                readonly property bool isArmed: root.armed === row.modelData.text
                                implicitHeight: 36; radius: 9
                                color: isArmed ? ColorUtils.applyAlpha(Appearance.colors.color4, 0.45)
                                     : miMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.35) : "transparent"
                                Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: 12
                                    Text { text: row.modelData.icon; font.family: Appearance.font.family; font.pixelSize: 15
                                           color: row.modelData.danger ? Appearance.colors.color13 : Appearance.colors.fg }
                                    Text { Layout.fillWidth: true
                                           text: mi.isArmed ? "Confirmer : " + row.modelData.text : row.modelData.text
                                           elide: Text.ElideRight
                                           font.family: Appearance.font.family; font.pixelSize: 13
                                           color: row.modelData.danger ? Appearance.colors.color13 : Appearance.colors.fg }
                                    Text { text: row.modelData.hint || ""; font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.dim }
                                }
                                MouseArea {
                                    id: miMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Action dangereuse : un 1er clic arme, le 2e confirme
                                        if (row.modelData.danger && !mi.isArmed) { root.armed = row.modelData.text; disarm.restart(); return }
                                        row.modelData.act()
                                        root.closeMenu()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
