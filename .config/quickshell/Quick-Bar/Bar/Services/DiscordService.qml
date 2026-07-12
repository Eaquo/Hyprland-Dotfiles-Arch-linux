pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// DiscordService — pont vers le serveur Discord via Bar/Scripts/discord_bridge.py.
//
// Orienté serveur : `channels` = salons texte, `currentChannel` = salon affiché.
// Un process long (Gateway) diffuse tous les messages du serveur ; on ne garde
// dans `model` que ceux du salon courant (ou de ses threads). Le changement de
// salon recharge l'historique via un process one-shot `--history`.
//
// Statut : "connecting" | "ready" | "no-token" | "error".
QtObject {
    id: root

    readonly property string _script:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/discord_bridge.py"

    property string status:  "connecting"
    property string botUser: ""

    property var    channels:       []    // [{ id, name, pos }]
    property string currentChannel: ""
    property string currentName:    ""

    property int maxMessages: 400
    property ListModel model: ListModel {}
    property var _seen: ({})               // id → true (dédup historique/live)

    signal messageAdded()
    signal downloadResult(bool ok, string msg)

    function selectChannel(id, name) {
        if (!id || id === root.currentChannel) return
        root.currentChannel = id
        root.currentName     = name || ""
        root.model.clear()
        root._seen = ({})
        histProc.command = ["python3", root._script, "--history", id]
        histProc.running = false
        histProc.running = true
    }

    function _append(o) {
        var belongs = (o.channel_id === root.currentChannel)
                   || (o.parent_id === root.currentChannel)
        if (!belongs) return
        if (o.id && root._seen[o.id]) return
        if (o.id) root._seen[o.id] = true
        root.model.append({
            mid:         o.id || "",
            author:      o.author || "?",
            authorId:    o.author_id || "",
            content:     o.content || "",
            ts:          o.ts || "",
            self:        o.self === true,
            thread:      o.thread || "",
            // Tableaux imbriqués → JSON string (ListModel ne les gère pas), reparsé
            // dans le delegate.
            embedsJson:  JSON.stringify(o.embeds || []),
            buttonsJson: JSON.stringify(o.buttons || [])
        })
        while (root.model.count > root.maxMessages)
            root.model.remove(0)
        root.messageAdded()
    }

    function _onLine(line) {
        if (!line || line.length === 0) return
        var o
        try { o = JSON.parse(line) } catch (e) { return }

        if (o.t === "msg") {
            root._append(o)
        } else if (o.t === "channels") {
            root.channels = o.list || []
            if (root.currentChannel === "" && root.channels.length > 0)
                root.selectChannel(root.channels[0].id, root.channels[0].name)
        } else if (o.t === "ready") {
            root.status  = "ready"
            root.botUser = o.user || ""
        } else if (o.t === "error") {
            root.status = (o.msg === "no-token") ? "no-token" : "error"
        }
        // history-end / thread : ignorés (pas besoin côté modèle)
    }

    // Envoi vers le salon courant. Un texte « /xxx » est traité comme commande
    // locale par le bridge (côté bot).
    function send(text) {
        if (!text || text.trim().length === 0 || root.currentChannel === "") return
        sendProc.command = ["python3", root._script, "--send", text, root.currentChannel]
        sendProc.running = false
        sendProc.running = true
    }

    // Déclenche le download d'un bouton « Télécharger » (custom_id) via bot.js.
    function triggerDownload(customId) {
        if (!customId || customId.length === 0) return
        dlProc.command = ["python3", root._script, "--dl", customId]
        dlProc.running = false
        dlProc.running = true
    }

    property var _bridge: Process {
        command: ["python3", root._script]
        running: true
        stdout: SplitParser { onRead: function(line) { root._onLine(line) } }
    }
    property var _dlProc: Process {
        id: dlProc
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var o = JSON.parse(line)
                    if (o.t === "dl") root.downloadResult(o.ok === true, o.msg || "")
                } catch (e) {}
            }
        }
    }
    property var _histProc: Process {
        id: histProc
        stdout: SplitParser { onRead: function(line) { root._onLine(line) } }
    }
    property var _sendProc: Process { id: sendProc }
}
