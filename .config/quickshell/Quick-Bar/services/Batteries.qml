pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.core

// Batteries — appareils sur batterie vus par UPower (souris Logitech via hidpp, casques Bluetooth…),
// suivis en direct par les signaux D-Bus d'UPower : aucun sondage. Partagé par le dashboard (Battery),
// la page Grid et le mode jeu. La manette Flydigi Vader 5 Pro (absente d'UPower) est lue sur son interface
// HID une fois par minute (scripts/system/vader5-battery.py, ~35 ms) et ajoutée comme un appareil de plus.
Singleton {
    id: root
    // appareils réels : ni secteur ni l'agrégat « DisplayDevice »
    readonly property var devices: UPower.devices.values.filter(d => d.type !== UPowerDeviceType.LinePower && d.nativePath !== "")
                                   .concat(vader ? [vader] : [])

    // + périphériques sans batterie (clavier) : affichés dans Devices et notifiés, mais pas dans les listes de batteries
    readonly property var all: devices.concat(keyboard ? [keyboard] : [])

    // Clavier (scripts/system/keyboard-info.py : vrais claviers USB/Bluetooth à voyants, souris écartées ici) : disposition, Verr. Maj, Verr. Num ; relu au branchement
    // (événement udev) et par refreshKeyboard() quand la page Devices s'affiche — pas de sondage
    property var keyboard: null
    Process {
        id: kbProc
        command: ["python3", Quickshell.shellDir + "/scripts/system/keyboard-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                // premier vrai clavier qui n'est pas une souris (le récepteur Logitech se présente aussi comme clavier)
                let list = []
                try { list = JSON.parse(text.trim()) } catch (e) {}
                const mice = root.devices.filter(d => d.type === UPowerDeviceType.Mouse).map(d => d.model)
                const k = (Array.isArray(list) ? list : []).find(x => mice.indexOf(x.model) < 0) || null
                root.keyboard = !k ? null : {
                    type: UPowerDeviceType.Keyboard, model: k.model, nativePath: "kbd:" + k.model,
                    percentage: -1, state: UPowerDeviceState.Unknown, timeToEmpty: 0, timeToFull: 0,
                    wired: true, noBattery: true, layout: k.layout, caps: k.caps, num: k.num
                }
            }
        }
    }
    function refreshKeyboard() { kbProc.running = false; kbProc.running = true }
    Component.onCompleted: refreshKeyboard()

    // Vader 5 Pro : même forme qu'un UPowerDevice (champs utilisés par les pages)
    property var vader: null
    property int vaderMiss: 0          // lectures vides d'affilée : une seule peut être un raté HID
    Process {
        id: vaderProc
        command: ["python3", Quickshell.shellDir + "/scripts/system/vader5-battery.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ").map(Number)          // pourcent état connexion
                if (p.length < 3 || isNaN(p[0])) {
                    // absente : on relit une fois avant de la déclarer déconnectée (pas de fausse notification)
                    if (root.vader && ++root.vaderMiss < 2) { vaderKick.restart(); return }
                    root.vader = null; return
                }
                root.vaderMiss = 0
                root.vader = {
                    type: UPowerDeviceType.GamingInput, model: "Flydigi Vader 5 Pro", nativePath: "vader5",
                    percentage: p[0] / 100, timeToEmpty: 0, timeToFull: 0,
                    state: p[1] === 1 ? UPowerDeviceState.Charging : p[1] === 2 ? UPowerDeviceState.FullyCharged
                                      : UPowerDeviceState.Discharging,
                    wired: p[2] === 1
                }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: vaderProc.running = true }
    // connexion / déconnexion : udev signale l'arrivée ou le départ d'une interface HID → relecture immédiate
    // (1,5 s le temps que la manette s'initialise), sans attendre la minute
    Process {
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "udevadm", "monitor", "--udev", "--subsystem-match=hidraw"]   // meurt avec Quick-Bar
        stdout: SplitParser { onRead: line => { if (/ (add|remove) /.test(line)) vaderKick.restart() } }
    }
    Timer { id: vaderKick; interval: 1500; onTriggered: { vaderProc.running = true; root.refreshKeyboard() } }

    // Photos : assets/devices/<slug du modèle>.png. Les manquantes listées dans assets/devices/devices.json
    // sont téléchargées une fois au démarrage (scripts/system/device-photos.py) ; photoRev recharge les images.
    property int photoRev: 0
    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/system/device-photos.py"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.photoRev++ }
    }
    function slug(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") }
    function photoPath(d) { return d && d.model ? Quickshell.shellDir + "/assets/devices/" + slug(d.model) + ".png" : "" }
    function photo(d) { return d && d.model ? "file://" + photoPath(d) + "?" + photoRev : "" }

    // Notification à la connexion et à la déconnexion d'un périphérique (photo, sinon icône du thème).
    // Rien au démarrage : les appareils déjà là sont seulement mémorisés. known garde une copie de chacun
    // (un UPowerDevice disparu n'est plus lisible) pour annoncer sa déconnexion avec sa dernière batterie.
    property var known: []
    property bool armed: false
    Timer { interval: 8000; running: true; onTriggered: root.armed = true }
    onAllChanged: {
        const now = all.map(d => ({ nativePath: d.nativePath, model: d.model, type: d.type, percentage: d.percentage,
                                        wired: d.wired }))
        const has = (list, d) => list.some(x => x.nativePath === d.nativePath)
        if (armed) {
            if (Config.get("devices.notify_connect", true)) now.filter(d => !has(known, d)).forEach(d => announce(d, true))
            if (Config.get("devices.notify_disconnect", true)) known.filter(d => !has(now, d)).forEach(d => announce(d, false))
        }
        known = now
        remember(now)
    }
    // mémorise les modèles vus (ShellState.devicesSeen), pour Réglages › Périphériques
    function remember(list) {
        const seen = ShellState.devicesSeen || []
        const add = list.filter(d => d.model && !seen.some(s => s.model === d.model)).map(d => ({ model: d.model, type: d.type }))
        if (add.length && ShellState._ready) ShellState.devicesSeen = seen.concat(add)
    }
    function announce(d, on) {
        const p = pct(d)
        // île dynamique (services/Island.qml) à la place de la notification, si elle est active
        if (Island.enabled && Config.get("island.devices", true) !== false) {
            const img = photoPath(d)
            Island.show({ title: (d.model || kind(d.type)) + (on ? " connecté" : " déconnecté"),
                          sub: on ? [kind(d.type), link(d), p > 0 ? p + " %" : ""].filter(x => x).join(" · ")
                                  : kind(d.type) + (p > 0 ? " · dernière batterie " + p + " %" : ""),
                          image: img, glyph: icon(d.type), accent: on ? Appearance.colors.accent : Appearance.colors.color13 })
            return
        }
        const what = on ? [kind(d.type), link(d), p > 0 ? p + " %" : ""].filter(x => x).join(" · ")
                        : kind(d.type) + (p > 0 ? " · dernière batterie " + p + " %" : "")
        const fallback = { [UPowerDeviceType.Mouse]: "input-mouse", [UPowerDeviceType.GamingInput]: "input-gaming",
                           [UPowerDeviceType.Keyboard]: "input-keyboard" }[d.type] || "audio-headphones"
        Quickshell.execDetached(["sh", "-c", '[ -f "$1" ] && i="$1" || i="$2"; notify-send -a Périphériques -i "$i" "$3" "$4"',
                                 "sh", photoPath(d), fallback, (d.model || kind(d.type)) + (on ? " connecté" : " déconnecté"), what])
    }
    // ── Batterie faible : notification avec la photo sous 20 % puis 10 % (une fois par seuil, remise à zéro à
    //    la charge ou au-dessus de 25 %). Suivi par appareil : la batterie d'UPower est notifiée en direct.
    property var lowSent: ({})            // nativePath → dernier seuil annoncé
    Instantiator {
        model: root.all
        delegate: QtObject {
            required property var modelData
            readonly property int p: modelData && !modelData.noBattery ? Math.round(modelData.percentage * 100) : -1
            readonly property bool ch: !!modelData && (modelData.state === UPowerDeviceState.Charging || modelData.state === UPowerDeviceState.FullyCharged)
            onPChanged: root.checkLow(modelData, p, ch)
            onChChanged: root.checkLow(modelData, p, ch)
            Component.onCompleted: root.checkLow(modelData, p, ch)
        }
    }
    function checkLow(d, p, ch) {
        if (!d || p < 0) return
        const k = d.nativePath, sent = lowSent[k] ?? 100
        const set = (v) => { const o = Object.assign({}, lowSent); o[k] = v; lowSent = o }
        if (ch || p >= 25) { if (sent < 100) set(100); return }
        const lvl = p <= 10 ? 10 : p <= 20 ? 20 : 100
        if (lvl >= sent || lvl === 100) return
        set(lvl)
        const bars = "▰".repeat(Math.max(1, Math.round(p / 10))) + "▱".repeat(10 - Math.max(1, Math.round(p / 10)))
        Quickshell.execDetached(["sh", "-c", '[ -f "$1" ] && i="$1" || i="battery-caution"; notify-send -a Périphériques -u critical -i "$i" "$2" "$3"',
                                 "sh", photoPath(d), (d.model || kind(d.type)) + " à " + p + " %",
                                 bars + "  " + (lvl === 10 ? "à recharger maintenant" : "pense à la recharger")])
    }

    // liaison : la Vader dit si elle est filaire, UPower donne le pilote (hidpp = récepteur Logitech, bluez = Bluetooth)
    function link(d) {
        if (!d) return ""
        if (d.wired !== undefined) return d.wired ? "USB" : "2,4 GHz"
        const p = d.nativePath || ""
        return p.indexOf("hidpp") >= 0 ? "2,4 GHz" : p.indexOf("bluez") >= 0 || p.indexOf("dev_") >= 0 ? "Bluetooth" : ""
    }
    readonly property var mouse: first([UPowerDeviceType.Mouse])
    readonly property var headset: first([UPowerDeviceType.Headphones, UPowerDeviceType.Headset])
    readonly property var pad: first([UPowerDeviceType.GamingInput])

    function first(types) { return devices.find(d => types.indexOf(d.type) >= 0) || null }
    function pct(d) { return d ? Math.round(d.percentage * 100) : -1 }

    function icon(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:       return "󰍽"
        case UPowerDeviceType.Keyboard:    return "󰌌"
        case UPowerDeviceType.Headphones:  return "󰋋"
        case UPowerDeviceType.Headset:     return "󰋎"
        case UPowerDeviceType.GamingInput: return "󰊴"
        case UPowerDeviceType.Phone:       return "󰏲"
        case UPowerDeviceType.Speakers:    return "󰓃"
        case UPowerDeviceType.Tablet:      return "󰓶"
        default:                           return "󰁹"
        }
    }
    function kind(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:       return "souris"
        case UPowerDeviceType.Keyboard:    return "clavier"
        case UPowerDeviceType.Headphones:  return "casque"
        case UPowerDeviceType.Headset:     return "casque micro"
        case UPowerDeviceType.GamingInput: return "manette"
        case UPowerDeviceType.Phone:       return "téléphone"
        case UPowerDeviceType.Speakers:    return "enceinte"
        default:                           return "batterie"
        }
    }
    function charging(d) { return !!d && d.state === UPowerDeviceState.Charging }
    function stateText(d) {
        if (!d) return "non connecté"
        switch (d.state) {
        case UPowerDeviceState.Charging:     return "en charge" + (d.timeToFull > 0 ? " · pleine dans " + dur(d.timeToFull) : "")
        case UPowerDeviceState.FullyCharged: return "chargée"
        case UPowerDeviceState.Discharging:  return "sur batterie" + (d.timeToEmpty > 0 ? " · " + dur(d.timeToEmpty) + " restantes" : "")
        case UPowerDeviceState.Empty:        return "vide"
        default:                             return "connecté"
        }
    }
    function dur(s) { const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60); return h ? h + " h " + (m < 10 ? "0" : "") + m : m + " min" }
    // même convention que SysData.lvl : critique color4, attention color12, sinon l'accent
    function col(p) { return p < 0 ? Appearance.colors.dim : p < 15 ? Appearance.colors.color4 : p < 30 ? Appearance.colors.color12 : Appearance.colors.accent }
}
