import QtQuick
import "../Common/"
import "../Common/functions/"
import "../Services/"

// DiscordChat — vue de l'onglet Discord (TouchPanel + Dashboard).
// Barre latérale de salons (serveur) + fil du salon courant (threads inclus,
// avec badge) + saisie. Alimenté par le singleton DiscordService.
//
// Saisie : clavier physique (le TouchPanel donne le focus clavier au layer).
// Un texte « /xxx » est traité comme commande locale par le bot.
Item {
    id: root

    function _initials(name) {
        var n = (name || "?").trim()
        return n.length > 0 ? n[0].toUpperCase() : "?"
    }
    function _hue(id) {
        var h = 0
        for (var i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) % 360
        return h
    }
    function _time(ts) {
        if (!ts) return ""
        var d = new Date(ts)
        return isNaN(d.getTime()) ? "" : Qt.formatTime(d, "HH:mm")
    }
    function _send() {
        if (input.text.trim().length === 0) return
        DiscordService.send(input.text)
        input.text = ""
    }
    // Rendu « riche » d'un texte Discord → HTML pour Text.StyledText :
    // timestamps <t:unix>, emojis custom <:name:id>, mentions, markdown **gras**.
    function _rich(s) {
        if (!s) return ""
        var t = String(s)
        t = t.replace(/<t:(\d+)(?::[tTdDfFR])?>/g, function(m, u) {
            var d = new Date(parseInt(u) * 1000)
            return isNaN(d.getTime()) ? m : Qt.formatDateTime(d, "dd/MM HH:mm")
        })
        t = t.replace(/<a?:(\w+):\d+>/g, ":$1:")
        t = t.replace(/<@!?\d+>/g, "@user").replace(/<#\d+>/g, "#salon").replace(/<@&\d+>/g, "@rôle")
        t = t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        t = t.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
        t = t.replace(/\*([^*\n]+)\*/g, "<i>$1</i>")
        t = t.replace(/__([^_]+)__/g, "<u>$1</u>")
        t = t.replace(/`([^`]+)`/g, '<font face="monospace">$1</font>')
        t = t.replace(/\n/g, "<br>")
        return t
    }

    // Couleur de fond d'un bouton selon son style Discord.
    function _btnBg(style, isLink) {
        if (isLink) return ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
        if (style === 1) return "#5865F2"   // primary
        if (style === 3) return "#3ba55d"   // success
        if (style === 4) return "#ed4245"   // danger
        return Qt.rgba(1, 1, 1, 0.10)        // secondary
    }

    // Toast de résultat de download (déclenché par DiscordService.downloadResult)
    property string _toast: ""
    property bool   _toastOk: true
    Connections {
        target: DiscordService
        function onDownloadResult(ok, msg) {
            root._toastOk = ok
            root._toast = (ok ? "⬇️ " : "⚠️ ") + msg
            toastTimer.restart()
        }
    }
    Timer { id: toastTimer; interval: 4000; onTriggered: root._toast = "" }

    Row {
        anchors.fill: parent
        spacing: 12

        // ══ Barre latérale : salons ══
        Rectangle {
            width: 190; height: parent.height
            radius: Appearance.cornerRadius
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.35)
            border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "󰙯  Serveur"
                    font.family: Appearance.font.family; font.pixelSize: 14
                    font.weight: Font.Bold; color: Appearance.colors.fg
                }

                ListView {
                    id: chanList
                    width: parent.width
                    height: parent.height - 30
                    spacing: 2
                    clip: true
                    model: DiscordService.channels
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool cur: modelData.id === DiscordService.currentChannel
                        width: chanList.width; height: 34
                        radius: 8
                        color: cur ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.18)
                                   : (chHov.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Text {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: 10; rightMargin: 10 }
                            text: "# " + modelData.name
                            elide: Text.ElideRight
                            font.family: Appearance.font.family; font.pixelSize: 13
                            font.weight: parent.cur ? Font.Bold : Font.Normal
                            color: parent.cur ? Appearance.colors.accent
                                              : Qt.rgba(1, 1, 1, 0.7)
                        }
                        HoverHandler { id: chHov }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: DiscordService.selectChannel(modelData.id, modelData.name)
                        }
                    }
                }
            }
        }

        // ══ Colonne chat ══
        Column {
            width: parent.width - 190 - parent.spacing
            height: parent.height
            spacing: 10

            // En-tête : salon courant + statut
            Row {
                width: parent.width
                spacing: 10
                Text {
                    text: DiscordService.currentName !== "" ? "# " + DiscordService.currentName : "Discord"
                    font.family: Appearance.font.family; font.pixelSize: 18
                    font.weight: Font.Bold; color: Appearance.colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: 1; height: 1 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusText.implicitWidth + 20; height: 24; radius: 12
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.width: 1
                    border.color: DiscordService.status === "ready"
                        ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.6)
                        : (DiscordService.status === "connecting" ? Qt.rgba(1,1,1,0.15) : "#f38ba8")
                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        font.family: Appearance.font.family; font.pixelSize: 11
                        color: Appearance.colors.dim
                        text: {
                            if (DiscordService.status === "ready")      return "connecté" + (DiscordService.botUser ? " · " + DiscordService.botUser : "")
                            if (DiscordService.status === "connecting") return "connexion…"
                            if (DiscordService.status === "no-token")   return "token manquant"
                            return "erreur"
                        }
                    }
                }
            }

            // Liste des messages
            Rectangle {
                width: parent.width
                height: parent.height - parent.spacing * 2 - 34 - inputRow.height
                radius: Appearance.cornerRadius
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.35)
                border.color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                clip: true

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: DiscordService.model.count === 0
                    font.family: Appearance.font.family; font.pixelSize: 13
                    color: Appearance.colors.dim
                    text: DiscordService.status === "no-token"
                        ? "Token du bot manquant.\nDépose-le dans ~/.config/quickshell/Quick-Bar/.discord_token puis recharge."
                        : (DiscordService.status === "error"
                            ? "Connexion impossible.\nVérifie le token, l'intent Message Content et les permissions du bot."
                            : "Aucun message dans ce salon.")
                }

                ListView {
                    id: lv
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    clip: true
                    model: DiscordService.model
                    boundsBehavior: Flickable.StopAtBounds

                    onCountChanged: positionViewAtEnd()
                    Component.onCompleted: positionViewAtEnd()
                    Connections {
                        target: DiscordService
                        function onMessageAdded() { lv.positionViewAtEnd() }
                    }

                    delegate: Item {
                        id: msgDelegate
                        width: lv.width
                        height: msgRow.height

                        readonly property var embeds:  { try { return JSON.parse(model.embedsJson  || "[]") } catch (e) { return [] } }
                        readonly property var buttons: { try { return JSON.parse(model.buttonsJson || "[]") } catch (e) { return [] } }

                        Row {
                            id: msgRow
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: Qt.hsla(root._hue(model.authorId) / 360, 0.5, 0.45, 1)
                                Text {
                                    anchors.centerIn: parent
                                    text: root._initials(model.author)
                                    font.family: Appearance.font.family
                                    font.pixelSize: 15; font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            Column {
                                id: msgBody
                                width: parent.width - 46
                                spacing: 4

                                Row {
                                    spacing: 8
                                    Text {
                                        text: model.author
                                        font.family: Appearance.font.family
                                        font.pixelSize: 13; font.weight: Font.Bold
                                        color: model.self ? Appearance.colors.accent : Appearance.colors.fg
                                    }
                                    Rectangle {
                                        visible: model.thread !== ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: thb.implicitWidth + 14; height: 18; radius: 9
                                        color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.18)
                                        Text {
                                            id: thb
                                            anchors.centerIn: parent
                                            text: "󰵜 " + model.thread
                                            font.family: Appearance.font.family; font.pixelSize: 10
                                            color: Appearance.colors.accent
                                        }
                                    }
                                    Text {
                                        text: root._time(model.ts)
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: "JetBrains Mono"; font.pixelSize: 10
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                    }
                                }

                                // Texte simple (souvent vide quand il y a un embed)
                                Text {
                                    width: parent.width
                                    visible: model.content !== ""
                                    text: root._rich(model.content)
                                    wrapMode: Text.WordWrap
                                    textFormat: Text.StyledText
                                    font.family: Appearance.font.family; font.pixelSize: 13
                                    color: Qt.rgba(1, 1, 1, 0.82)
                                }

                                // ── Embeds ────────────────────────────────────────────────
                                Repeater {
                                    model: msgDelegate.embeds
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: msgBody.width
                                        implicitHeight: embCol.implicitHeight + 16
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.04)

                                        // Barre d'accent (couleur de l'embed)
                                        Rectangle {
                                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                            width: 3; radius: 2
                                            color: modelData.color !== "" ? modelData.color : Appearance.colors.accent
                                        }

                                        Column {
                                            id: embCol
                                            anchors { left: parent.left; right: parent.right; top: parent.top
                                                      leftMargin: 14; rightMargin: 10; topMargin: 8 }
                                            spacing: 5

                                            // Titre + miniature à droite
                                            Row {
                                                width: parent.width
                                                spacing: 10
                                                Column {
                                                    width: parent.width - (thumbImg.visible ? 68 : 0)
                                                    spacing: 3
                                                    Text {
                                                        width: parent.width
                                                        visible: modelData.author !== ""
                                                        text: modelData.author
                                                        elide: Text.ElideRight
                                                        font.family: Appearance.font.family; font.pixelSize: 11
                                                        color: Appearance.colors.dim
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        visible: modelData.title !== ""
                                                        text: modelData.title
                                                        wrapMode: Text.WordWrap
                                                        font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold
                                                        color: modelData.url !== "" ? Appearance.colors.accent : Appearance.colors.fg
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            enabled: modelData.url !== ""
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: Qt.openUrlExternally(modelData.url)
                                                        }
                                                    }
                                                    Text {
                                                        width: parent.width
                                                        visible: modelData.description !== ""
                                                        text: root._rich(modelData.description)
                                                        wrapMode: Text.WordWrap
                                                        textFormat: Text.StyledText
                                                        font.family: Appearance.font.family; font.pixelSize: 12
                                                        color: Qt.rgba(1, 1, 1, 0.75)
                                                    }
                                                }
                                                Image {
                                                    id: thumbImg
                                                    width: 58; height: 82
                                                    visible: modelData.thumb !== "" && status === Image.Ready
                                                    source: modelData.thumb
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }

                                            // Champs (inline = 1/3 de largeur, sinon pleine largeur)
                                            Flow {
                                                width: parent.width
                                                spacing: 10
                                                Repeater {
                                                    model: modelData.fields
                                                    delegate: Column {
                                                        required property var modelData
                                                        width: modelData.inline ? (embCol.width - 20) / 3 : embCol.width
                                                        spacing: 1
                                                        Text {
                                                            width: parent.width
                                                            text: modelData.name
                                                            elide: Text.ElideRight
                                                            font.family: Appearance.font.family; font.pixelSize: 11; font.weight: Font.Bold
                                                            color: Appearance.colors.fg
                                                        }
                                                        Text {
                                                            width: parent.width
                                                            text: root._rich(modelData.value)
                                                            wrapMode: Text.WordWrap
                                                            textFormat: Text.StyledText
                                                            font.family: Appearance.font.family; font.pixelSize: 11
                                                            color: Qt.rgba(1, 1, 1, 0.65)
                                                        }
                                                    }
                                                }
                                            }

                                            // Grande image
                                            Image {
                                                width: Math.min(parent.width, 360)
                                                visible: modelData.image !== "" && status === Image.Ready
                                                source: modelData.image
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }

                                            Text {
                                                width: parent.width
                                                visible: modelData.footer !== ""
                                                text: modelData.footer
                                                elide: Text.ElideRight
                                                font.family: Appearance.font.family; font.pixelSize: 10
                                                color: Qt.rgba(1, 1, 1, 0.4)
                                            }
                                        }
                                    }
                                }

                                // ── Boutons ───────────────────────────────────────────────
                                Flow {
                                    width: msgBody.width
                                    spacing: 6
                                    visible: msgDelegate.buttons.length > 0
                                    Repeater {
                                        model: msgDelegate.buttons
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property string cid: modelData.custom_id || ""
                                            readonly property bool isLink: modelData.style === 5 && modelData.url !== ""
                                            // Actions gérées via l'endpoint bot.js : télécharger / play / pause / annuler.
                                            readonly property bool isAction: /^dl_(confirm|play|pause|cancel)/.test(cid)
                                            readonly property bool isCancel: cid.indexOf("dl_cancel") === 0
                                            readonly property bool clickable: isLink || isAction
                                            height: 30
                                            width: btnLabel.implicitWidth + 24
                                            radius: 6
                                            color: isCancel ? "#ed4245"
                                                 : isAction ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                                 : root._btnBg(modelData.style, isLink)
                                            opacity: clickable ? 1 : 0.5   // custom_id non géré : non cliquable via l'API
                                            Text {
                                                id: btnLabel
                                                anchors.centerIn: parent
                                                text: (parent.isLink ? "🔗 " : "") + modelData.label
                                                font.family: Appearance.font.family; font.pixelSize: 12
                                                color: parent.isCancel ? "#ffffff"
                                                    : parent.isAction ? Appearance.colors.bg
                                                    : ((modelData.style === 2 && !parent.isLink) ? Appearance.colors.fg : "#ffffff")
                                            }
                                            HoverHandler { cursorShape: parent.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: parent.clickable
                                                onClicked: {
                                                    if (parent.isLink) Qt.openUrlExternally(modelData.url)
                                                    else DiscordService.triggerDownload(parent.cid)
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

            // Saisie
            Row {
                id: inputRow
                width: parent.width
                height: 44
                spacing: 8

                Rectangle {
                    height: parent.height
                    width: parent.width - parent.spacing - sendBtn.width
                    radius: Appearance.cornerRadius
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.color: input.activeFocus ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.5)
                                                    : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Appearance.font.family; font.pixelSize: 13
                        color: Appearance.colors.fg
                        clip: true
                        enabled: DiscordService.status === "ready" && DiscordService.currentChannel !== ""
                        onAccepted: root._send()
                    }
                    Text {
                        anchors.fill: input
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text.length === 0
                        text: input.enabled ? "Message #" + DiscordService.currentName + "  (ou /commande)" : "Indisponible"
                        elide: Text.ElideRight
                        font.family: Appearance.font.family; font.pixelSize: 13
                        color: Qt.rgba(1, 1, 1, 0.3)
                    }
                }

                Rectangle {
                    id: sendBtn
                    height: parent.height; width: 56
                    radius: Appearance.cornerRadius
                    color: input.text.length > 0 ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                                 : ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    Text {
                        anchors.centerIn: parent; text: "󰤾"
                        font.family: Appearance.font.family; font.pixelSize: 20
                        color: input.text.length > 0 ? Appearance.colors.bg : Appearance.colors.dim
                    }
                    MouseArea { anchors.fill: parent; onClicked: root._send() }
                }
            }
        }
    }

    // Toast (résultat de download)
    Rectangle {
        visible: root._toast !== ""
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 60 }
        width: tToast.implicitWidth + 32; height: 40; radius: 20
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.96)
        border.width: 1
        border.color: root._toastOk ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.7) : "#f38ba8"
        Text {
            id: tToast
            anchors.centerIn: parent; text: root._toast
            font.family: Appearance.font.family; font.pixelSize: 13
            color: Appearance.colors.fg
        }
    }
}
