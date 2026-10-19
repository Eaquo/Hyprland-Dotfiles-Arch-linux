pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.core

// NotificationService — le démon de notifications de Quick-Bar (remplace swaync).
//   list    : historique (le centre de notifications : panels/NotifCenter.qml) — des copies : une
//             notification fermée par l'appli ou expirée y reste (Discord ferme les siennes
//             aussitôt affichées) ; seul un « effacer » de l'utilisateur la retire
//   toasts  : notifications affichées en ce moment (panels/NotifToasts.qml)
//   [notifications] timeout (s, 6) · max (toasts visibles, 4) · « Ne pas déranger » = ShellState.dnd
NotificationServer {
    id: root

    bodyMarkupSupported: true
    bodySupported: true
    bodyImagesSupported: true
    bodyHyperlinksSupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true
    keepOnReload: true

    signal notificationAdded(var notification)

    property var list: []
    property var toasts: []
    readonly property int count: list.length
    property var times: ({})               // id → heure de réception
    readonly property int timeoutS: Number(Config.get("notifications.timeout", 6))
    readonly property int maxToasts: Number(Config.get("notifications.max", 4))

    property bool _ready: false
    property Timer _startupTimer: Timer { interval: 500; running: true; onTriggered: root._ready = true }

    onNotification: function(n) {
        n.tracked = true
        if (root.list.some(e => e.live === n)) return
        const t = Object.assign({}, root.times); t[n.id] = Date.now(); root.times = t
        const e = root._entry(n)
        root.list = [e, ...root.list.filter(x => x.id !== n.id)]
        n.closed.connect(function(reason) {
            root.toasts = root.toasts.filter(x => x !== n)
            if (reason === NotificationCloseReason.Dismissed) { root._drop(e.id); return }
            // gardée dans l'historique, sans ce qui meurt avec la notification (actions, image en mémoire)
            const img = /^(\/|file:)/.test(e.image) ? e.image : ""
            root.list = root.list.map(x => x.id === e.id ? Object.assign({}, x, { live: null, actions: [], image: img }) : x)
        })
        if (ShellState.dnd && n.urgency !== NotificationUrgency.Critical) return
        if (!root._ready) return
        root.toasts = [n, ...root.toasts].slice(0, root.maxToasts)
        root.notificationAdded(n)
    }

    // copie pour l'historique ; dismiss() = l'effacer (et fermer la notification si elle vit encore)
    function _entry(n) {
        return { id: n.id, appName: n.appName, appIcon: n.appIcon, image: n.image, summary: n.summary, body: n.body,
                 urgency: n.urgency, actions: n.actions, live: n, dismiss: function() { root._drop(n.id) } }
    }
    function _drop(id) {
        const e = list.find(x => x.id === id)
        list = list.filter(x => x.id !== id)
        if (e && e.live) { const l = e.live; e.live = null; l.dismiss() }
    }
    // retirer un toast (la notification reste dans l'historique)
    function hideToast(n) { toasts = toasts.filter(x => x !== n) }
    function dismissAll() { for (const e of [...list]) _drop(e.id) }
    function ago(n) {
        const s = Math.round((Date.now() - (times[n.id] || Date.now())) / 1000)
        return s < 60 ? "à l'instant" : s < 3600 ? "il y a " + Math.floor(s / 60) + " min" : "il y a " + Math.floor(s / 3600) + " h"
    }
    // délai d'un toast : celui demandé par l'application, sinon le réglage ; jamais pour « critique »
    function toastMs(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0
        return n.expireTimeout > 0 ? n.expireTimeout : timeoutS * 1000
    }
}
