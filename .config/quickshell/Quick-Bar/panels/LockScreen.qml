import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import qs.core
import qs.core.functions

// LockScreen — verrouillage de session Quick-Bar (ext-session-lock : si Quick-Bar plante, la session
// reste verrouillée). Mot de passe vérifié par PAM (/etc/pam.d/hyprlock).
//   `qs ipc call lock lock` · SUPER+L · loginctl lock-session (lock_cmd de hypridle)
//   Verrouillage et extinction de l'écran automatiques : [lock] auto_minutes · screen_off_minutes
//   (0 = jamais ; les blocages de veille — vidéo, jeu — sont respectés). Le fond suit [session] style.
Scope {
    id: root

    property bool locked: false
    property string status: ""           // message sous le champ (erreur PAM…)
    property bool busy: pam.active
    property int fails: 0

    function lock() { if (!locked) { status = ""; fails = 0; locked = true } }
    IpcHandler { target: "lock"; function lock() { root.lock() } }   // pas de « unlock » par IPC, volontairement

    // ── PAM ───────────────────────────────────────────────────────────────
    property string _pending: ""
    function tryUnlock(pw) {
        if (pw === "" || pam.active) return
        status = ""; _pending = pw
        pam.start()
    }
    PamContext {
        id: pam
        config: "hyprlock"
        onResponseRequiredChanged: if (responseRequired && root._pending !== "") { respond(root._pending); root._pending = "" }
        onPamMessage: if (messageIsError) root.status = message
        onCompleted: (result) => {
            if (result === PamResult.Success) { root.unlocking = true; unlockT.restart() }
            else { root.fails++; root.status = root.fails > 2 ? "Mot de passe incorrect (" + root.fails + " essais)" : "Mot de passe incorrect"; root.shake++ }
        }
        onError: (err) => root.status = "Erreur d'authentification"
    }
    property int shake: 0
    property bool unlocking: false
    // laisser jouer l'animation de sortie, puis rendre la session
    Timer { id: unlockT; interval: Appearance.dur(450); onTriggered: { root.locked = false; root.unlocking = false } }

    // ── minuterie : verrouillage et écran éteint ──────────────────────────
    readonly property int autoMin: Number(Config.get("lock.auto_minutes", 0))
    readonly property int offMin: Number(Config.get("lock.screen_off_minutes", 0))
    IdleMonitor {
        enabled: root.autoMin > 0 && !root.locked
        timeout: root.autoMin * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }
    Process { id: dpms }
    IdleMonitor {
        enabled: root.offMin > 0
        timeout: root.offMin * 60
        respectInhibitors: true
        onIsIdleChanged: { dpms.command = ["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"]; dpms.running = true }
    }

    readonly property string style: String(Config.get("session.style", "matrix"))
    readonly property color glow: Appearance.contrastRatio(Appearance.colors.accent, "#000000") < 4
                                  ? Qt.lighter(Appearance.colors.accent, 1.6) : Appearance.colors.accent
    readonly property string wallSrc: WallpaperState.videoMode
        ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
        : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
    readonly property var player: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null

    // un chiffre qui roule quand il change (horloge de l'écran Minimal)
    component LockDigit: Item {
        id: dg
        required property var surf          // la surface (pour surf.st et sa hauteur)
        property string ch: "0"
        property real d: 0
        property string cur: ""
        property string prev: ""
        property real roll: 1
        width: tm.advanceWidth; height: tm.height
        clip: true
        onChChanged: { prev = cur; cur = ch; if (prev !== "") rollA.restart() }
        Component.onCompleted: cur = ch
        NumberAnimation { id: rollA; target: dg; property: "roll"; from: 0; to: 1; duration: Appearance.dur(650); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        TextMetrics { id: tm; text: "0"; font.family: "JetBrains Mono"; font.pixelSize: Math.min(dg.surf.height * 0.2, 260); font.weight: Font.Thin }
        Text { y: -dg.roll * dg.height; visible: dg.roll < 1; text: dg.prev; font: tm.font; color: Appearance.colors.fg; opacity: 1 - dg.roll }
        Text {
            readonly property real k: dg.surf.st(dg.d, 0.35)
            y: (1 - dg.roll) * dg.height + (1 - k) * dg.height * 0.6
            opacity: k
            text: dg.cur; font: tm.font; color: Appearance.colors.fg
        }
    }

    WlSessionLock {
        locked: root.locked
        WlSessionLockSurface {
            id: surf
            color: "black"
            readonly property bool main: !Config.isTouch(screen)
            property real intro: 0
            Component.onCompleted: introA.start()
            NumberAnimation { id: introA; target: surf; property: "intro"; from: 0; to: 1; duration: Appearance.dur(900); easing.type: Easing.OutCubic }
            readonly property real outro: root.unlocking ? 1 : 0
            function st(d, span) { const t = Math.max(0, Math.min(1, (intro - d) / span)); return 1 - Math.pow(1 - t, 3) }

            Item {
                id: scene
                anchors.fill: parent
                opacity: 1 - outroV.v
                scale: 1 + outroV.v * 0.06
                QtObject { id: outroV; property real v: surf.outro; Behavior on v { NumberAnimation { duration: Appearance.dur(420); easing.type: Easing.InCubic } } }

                // fond : fond d'écran flouté (ou pluie Matrix / glitch Netrunner selon le style)
                Image { id: wall; anchors.fill: parent; source: root.wallSrc; fillMode: Image.PreserveAspectCrop; visible: false
                        asynchronous: true; sourceSize.width: Math.round(parent.width / 2) }
                MultiEffect {
                    anchors.fill: parent; source: wall
                    visible: root.style !== "matrix" && root.style !== "cyber"
                    blurEnabled: true; blur: 1; blurMax: 64; saturation: -0.15
                    opacity: surf.st(0, 0.4); scale: 1.1 - 0.1 * surf.st(0, 0.8)
                }
                Rectangle { id: black; anchors.fill: parent; color: "#000000"; visible: false; layer.enabled: true }
                ShaderEffect {
                    id: lockFx
                    anchors.fill: parent
                    visible: root.style === "matrix" || root.style === "cyber"
                    opacity: surf.st(0, 0.4)
                    property variant source: wall.status === Image.Ready ? wall : black
                    property real intensity: root.style === "cyber" ? 0.7 : 0.9
                    property real time: 0
                    property vector2d resolution: Qt.vector2d(width, height)
                    property vector4d accent: Qt.vector4d(root.glow.r, root.glow.g, root.glow.b, 1)
                    fragmentShader: Qt.resolvedUrl("../wallpaper/shaders/" + (root.style === "cyber" ? "cyberpunk" : "matrix") + ".frag.qsb")
                    // la pluie défile (plus vite pendant la vérification du mot de passe)
                    FrameAnimation { running: lockFx.visible; onTriggered: lockFx.time += frameTime * (root.busy ? 2.5 : 1) }
                }
                Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: (root.style === "matrix" || root.style === "cyber" ? 0.45 : 0.62) * surf.st(0, 0.3) }

                // heure, date
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * (surf.main ? 0.2 : 0.18)
                    spacing: 6
                    opacity: surf.st(0.1, 0.4)
                    transform: Translate { y: (1 - surf.st(0.1, 0.5)) * 40 }
                    // horloge comme l'écran de session Minimal : chiffres qui roulent, deux-points qui battent
                    // la seconde, trait des secondes dessous
                    Item {
                        id: clock
                        anchors.horizontalCenter: parent.horizontalCenter
                        property var now: new Date()
                        property real secFrac: 0
                        Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
                        FrameAnimation { running: true; onTriggered: { const d = new Date(); clock.secFrac = (d.getSeconds() + d.getMilliseconds() / 1000) / 60 } }
                        readonly property string hm: Qt.formatTime(now, "HHmm")
                        readonly property real big: Math.min(surf.height * 0.2, 260)
                        width: digits.width; height: digits.height + 14
                        Row {
                            id: digits
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.glow; shadowBlur: 1; shadowOpacity: 0.45
                                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; autoPaddingEnabled: true }
                            LockDigit { surf: surf; ch: clock.hm[0]; d: 0.10 }
                            LockDigit { surf: surf; ch: clock.hm[1]; d: 0.15 }
                            Text {
                                text: ":"; font.family: "JetBrains Mono"; font.weight: Font.Thin; font.pixelSize: clock.big
                                color: root.glow
                                opacity: surf.st(0.2, 0.3) * (0.35 + 0.65 * Math.abs(Math.cos(Math.PI * clock.secFrac * 60)))
                            }
                            LockDigit { surf: surf; ch: clock.hm[2]; d: 0.25 }
                            LockDigit { surf: surf; ch: clock.hm[3]; d: 0.30 }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: digits.width * surf.st(0.3, 0.4); height: 2; radius: 1
                            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                            Rectangle { height: 2; radius: 1; width: parent.width * clock.secFrac; color: root.glow }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM").toUpperCase()
                        font.family: Appearance.font.family; font.pixelSize: 16; font.letterSpacing: 5; color: Appearance.colors.dim
                    }
                }

                // avatar, nom, mot de passe (écran principal)
                Column {
                    visible: surf.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.56
                    spacing: 18
                    opacity: surf.st(0.3, 0.4)
                    transform: Translate {
                        y: (1 - surf.st(0.3, 0.5)) * 30
                        x: shakeA.running ? shakeX.v : 0
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96; height: 96; radius: 48
                        color: Appearance.colors.color0
                        border.width: 2; border.color: root.busy ? root.glow : ColorUtils.applyAlpha(root.glow, 0.6)
                        Image { anchors.fill: parent; anchors.margins: 3; source: "file://" + Config.avatar
                                fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(192, 192); asynchronous: true
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: avMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 } }
                        Rectangle { id: avMask; anchors.fill: parent; anchors.margins: 3; radius: width / 2; visible: false; layer.enabled: true }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Config.userName
                        font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.DemiBold; color: Appearance.colors.fg
                    }
                    Rectangle {
                        id: field
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 380; height: 52; radius: 26
                        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.75)
                        border.width: 2
                        border.color: root.status !== "" ? Appearance.colors.color1 : pw.activeFocus ? root.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.2)
                        Behavior on border.color { ColorAnimation { duration: Appearance.dur(200) } }
                        TextInput {
                            id: pw
                            anchors.fill: parent; anchors.leftMargin: 26; anchors.rightMargin: 52
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password; passwordCharacter: "●"
                            font.family: Appearance.font.family; font.pixelSize: 18; font.letterSpacing: 3
                            color: Appearance.colors.fg
                            enabled: !root.busy
                            focus: surf.main
                            Component.onCompleted: if (surf.main) forceActiveFocus()
                            onAccepted: { root.tryUnlock(text); text = "" }
                            onTextChanged: if (text !== "") root.status = ""
                            Text { visible: pw.text === ""; anchors.verticalCenter: parent.verticalCenter
                                   text: root.busy ? "vérification…" : "mot de passe"
                                   font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.dim }
                        }
                        Text { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                               text: root.busy ? "󰔟" : "󰌾"; font.family: Appearance.font.family; font.pixelSize: 18; color: root.glow
                               RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.status
                        visible: text !== ""
                        font.family: Appearance.font.family; font.pixelSize: 14; color: Qt.lighter(Appearance.colors.color1, 1.6)
                    }
                    QtObject { id: shakeX; property real v: 0 }
                    SequentialAnimation {
                        id: shakeA
                        NumberAnimation { target: shakeX; property: "v"; to: -14; duration: 50 }
                        NumberAnimation { target: shakeX; property: "v"; to: 12; duration: 60 }
                        NumberAnimation { target: shakeX; property: "v"; to: -8; duration: 60 }
                        NumberAnimation { target: shakeX; property: "v"; to: 0; duration: 60 }
                    }
                    Connections { target: root; function onShakeChanged() { shakeA.restart() } }
                }

                // en cours de lecture (bas de l'écran principal)
                Text {
                    visible: surf.main && root.player !== null
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 40
                    opacity: 0.7 * surf.st(0.5, 0.3)
                    text: root.player ? "󰎈  " + (root.player.trackTitle || "") + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "") : ""
                    font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.fg
                }
            }
            MouseArea { anchors.fill: parent; onClicked: pw.forceActiveFocus() }
        }
    }
}
