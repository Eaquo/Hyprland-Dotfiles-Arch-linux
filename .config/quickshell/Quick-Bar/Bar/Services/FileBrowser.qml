import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

// FileBrowser — onglet "Files" du dashboard, dans l'esprit de yazi.
//
//   • Panneau gauche  : liste du dossier (FolderListModel natif), dossiers
//     en premier, fichiers cachés affichés. Clic = sélection/aperçu,
//     double-clic = entrer dans un dossier / ouvrir un fichier.
//   • Panneau droit   : aperçu coloré via `bat --theme=ansi` dont les codes
//     ANSI 16-couleurs sont mappés sur la palette wallust (Appearance.colors).
//     Les images sont affichées directement.
//   • Actions         : Ouvrir (xdg-open), Copier le chemin (wl-copy),
//     Renommer (mv), Supprimer (gio trash, avec confirmation).
//
// Tout le chrome utilise la palette wallust via Appearance.

Item {
    id: root
    focus: true

    // ── État ──────────────────────────────────────────────────────────────────
    readonly property string homePath: Quickshell.env("HOME") || "/"
    property string currentPath: homePath

    property string selPath:   ""
    property string selName:   ""
    property string selSuffix: ""
    property bool   selIsDir:  false
    property real   selSize:   0

    property string previewRich:        ""
    property bool   previewIsImage:     false
    property string previewImageSource: ""

    property bool deleting: false
    property bool renaming: false

    // ── Recherche récursive (fd) ──────────────────────────────────────────────
    property string searchQuery:   ""
    property var    searchResults: []
    readonly property bool searchActive: searchQuery.trim().length > 0

    readonly property var _imageExts: ["png","jpg","jpeg","gif","webp","bmp","svg","avif"]

    Component.onCompleted: root.currentPath = root.homePath

    // ── Navigation ────────────────────────────────────────────────────────────
    function parentOf(p) {
        if (p === "/" || p === "") return "/"
        var s = p.replace(/\/+$/, "")
        var i = s.lastIndexOf("/")
        return i <= 0 ? "/" : s.substring(0, i)
    }
    function basename(p) {
        var s = p.replace(/\/+$/, "")
        var i = s.lastIndexOf("/")
        return i < 0 ? s : s.substring(i + 1)
    }
    function enterDir(p) {
        searchField.text = ""          // quitte le mode recherche
        root.clearSelection()
        root.currentPath = p
    }

    function relDisplay(p) {
        var base = root.currentPath.replace(/\/+$/, "")
        return (p.indexOf(base + "/") === 0) ? p.substring(base.length + 1) : p
    }
    function goUp() { root.enterDir(root.parentOf(root.currentPath)) }

    function clearSelection() {
        root.selPath = ""; root.selName = ""; root.selSuffix = ""
        root.selIsDir = false; root.selSize = 0
        root.previewRich = ""; root.previewIsImage = false; root.previewImageSource = ""
        root.deleting = false; root.renaming = false
    }

    function select(path, name, suffix, isDir, size) {
        root.selPath = path; root.selName = name
        root.selSuffix = (suffix || "").toLowerCase()
        root.selIsDir = isDir; root.selSize = size || 0
        root.deleting = false; root.renaming = false
        if (isDir) {
            root.previewRich = ""; root.previewIsImage = false; root.previewImageSource = ""
        } else if (root._imageExts.indexOf(root.selSuffix) !== -1) {
            root.previewIsImage = true
            root.previewImageSource = "file://" + path
            root.previewRich = ""
        } else {
            root.previewIsImage = false; root.previewImageSource = ""
            previewDebounce.restart()
        }
    }

    function refresh() {
        var f = dirModel.folder
        dirModel.folder = ""
        dirModel.folder = f
    }

    function humanSize(b) {
        if (b < 1024) return b + " B"
        if (b < 1048576) return (b / 1024).toFixed(1) + " K"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + " M"
        return (b / 1073741824).toFixed(1) + " G"
    }

    function iconFor(isDir, suffix) {
        if (isDir) return "󰉋"
        var s = (suffix || "").toLowerCase()
        if (root._imageExts.indexOf(s) !== -1) return "󰋩"
        if (["mp3","flac","wav","ogg","m4a","opus"].indexOf(s) !== -1) return "󰎆"
        if (["mp4","mkv","webm","avi","mov"].indexOf(s) !== -1) return "󰕧"
        if (["zip","tar","gz","xz","zst","7z","rar"].indexOf(s) !== -1) return "󰗄"
        if (["pdf"].indexOf(s) !== -1) return "󰈦"
        if (["sh","bash","zsh","py","js","qml","lua","c","cpp","rs","go"].indexOf(s) !== -1) return "󰈮"
        return "󰈔"
    }

    // ── ANSI (bat) → texte riche, couleurs mappées sur wallust ────────────────
    function ansiToRich(raw) {
        var pal = [
            Appearance.colors.color0,  Appearance.colors.color1,  Appearance.colors.color2,  Appearance.colors.color3,
            Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,  Appearance.colors.color7,
            Appearance.colors.color8,  Appearance.colors.color9,  Appearance.colors.color10, Appearance.colors.color11,
            Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14, Appearance.colors.color15
        ].map(function(c) { return c.toString() })
        var defFg = Appearance.colors.fg.toString()

        var curFg = null, bold = false, italic = false
        function applyCodes(codes) {
            var parts = codes.length === 0 ? ["0"] : codes.split(";")
            for (var k = 0; k < parts.length; k++) {
                var v = parseInt(parts[k])
                if (isNaN(v) || v === 0)      { curFg = null; bold = false; italic = false }
                else if (v === 1)              bold = true
                else if (v === 3)              italic = true
                else if (v === 22)             bold = false
                else if (v === 23)             italic = false
                else if (v >= 30 && v <= 37)   curFg = pal[v - 30]
                else if (v >= 90 && v <= 97)   curFg = pal[v - 90 + 8]
                else if (v === 39)             curFg = null
            }
        }
        function esc(ch) {
            switch (ch) {
                case '&':  return '&amp;'
                case '<':  return '&lt;'
                case '>':  return '&gt;'
                case ' ':  return '&#160;'
                case '\t': return '&#160;&#160;&#160;&#160;'
                case '\n': return '<br/>'
                case '\r': return ''
                default:   return ch
            }
        }
        function openSpan() {
            var style = "color:" + (curFg || defFg)
            if (bold)   style += ";font-weight:bold"
            if (italic) style += ";font-style:italic"
            return "<span style=\"" + style + "\">"
        }

        var out = "", spanOpen = false
        var i = 0, n = raw.length
        while (i < n) {
            var ch = raw.charAt(i)
            if (ch === '\x1b' && raw.charAt(i + 1) === '[') {
                var j = i + 2, codes = ""
                while (j < n && raw.charAt(j) !== 'm') { codes += raw.charAt(j); j++ }
                applyCodes(codes)
                if (spanOpen) { out += "</span>"; spanOpen = false }
                i = j + 1
                continue
            }
            if (!spanOpen) { out += openSpan(); spanOpen = true }
            out += esc(ch)
            i++
        }
        if (spanOpen) out += "</span>"
        return out
    }

    // ── Modèle du dossier courant ─────────────────────────────────────────────
    FolderListModel {
        id: dirModel
        folder:        "file://" + root.currentPath
        showDirsFirst: true
        showHidden:    true
        showDotAndDotDot: false
        sortField:     FolderListModel.Name
        nameFilters:   ["*"]
    }

    // ── Aperçu bat (debounce + capture) ───────────────────────────────────────
    Timer {
        id: previewDebounce
        interval: 90; repeat: false
        onTriggered: {
            if (root.selPath === "" || root.selIsDir || root.previewIsImage) return
            batProc.command = [
                "bat", "--color=always", "--theme=ansi", "--style=numbers",
                "--wrap=never", "--line-range=:800", "--paging=never",
                "--", root.selPath
            ]
            batProc.running = false
            batProc.running = true
        }
    }

    Process {
        id: batProc
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text
                if (!t || t.length === 0) {
                    root.previewRich = "<span style=\"color:" + Appearance.colors.dim.toString()
                                     + "\">Aperçu non disponible (binaire ou vide)</span>"
                    return
                }
                root.previewRich = root.ansiToRich(t)
            }
        }
    }

    // ── Recherche fd (debounce + capture) ─────────────────────────────────────
    Timer {
        id: searchDebounce
        interval: 180; repeat: false
        onTriggered: root.runSearch()
    }

    function runSearch() {
        var q = root.searchQuery.trim()
        if (q.length === 0) { root.searchResults = []; return }
        // fd récursif, insensible à la casse (smart-case), littéral (--fixed-strings),
        // --full-path → matche aussi sur le chemin (ex. ".config/hyp"), chemins absolus ;
        // on annote chaque résultat 'd' (dossier) ou 'f' (fichier).
        fdProc.command = [
            "bash", "-c",
            "fd --hidden --full-path --color=never --fixed-strings --absolute-path -- \"$1\" \"$2\" 2>/dev/null " +
            "| head -n 500 " +
            "| while IFS= read -r p; do if [ -d \"$p\" ]; then printf 'd\\t%s\\n' \"$p\"; else printf 'f\\t%s\\n' \"$p\"; fi; done",
            "_", q, root.currentPath
        ]
        fdProc.running = false
        fdProc.running = true
    }

    Process {
        id: fdProc
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var res = []
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i]
                    var tab = ln.indexOf("\t")
                    if (tab < 0) continue
                    var p = ln.substring(tab + 1)
                    if (p === "") continue
                    var nm = root.basename(p)
                    var dot = nm.lastIndexOf(".")
                    res.push({
                        isDir:  ln.substring(0, tab) === "d",
                        path:   p,
                        name:   nm,
                        suffix: (dot > 0) ? nm.substring(dot + 1) : ""
                    })
                }
                root.searchResults = res
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    Process { id: openProc;  command: ["xdg-open", ""] }
    Process { id: copyProc;  command: ["wl-copy", ""] }
    Process {
        id: trashProc
        command: ["gio", "trash", "--", ""]
        onRunningChanged: if (!running) { root.clearSelection(); root.refresh() }
    }
    Process {
        id: renameProc
        command: ["mv", "--", "", ""]
        onRunningChanged: if (!running) { root.refresh() }
    }

    // Médias / binaires → appli système ; reste (texte, code, configs) → nvim dans kitty.
    readonly property var _xdgExts: [
        "png","jpg","jpeg","gif","webp","bmp","svg","avif",
        "mp4","mkv","webm","avi","mov","mp3","flac","wav","ogg","m4a","opus",
        "pdf","zip","tar","gz","xz","zst","7z","rar","odt","ods","odp","docx","xlsx","pptx"
    ]
    function doOpen() {
        if (root.selPath === "") return
        if (root.selIsDir) { root.enterDir(root.selPath); return }
        if (root._xdgExts.indexOf(root.selSuffix) !== -1)
            openProc.command = ["setsid", "-f", "xdg-open", root.selPath]
        else
            openProc.command = ["setsid", "-f", "kitty", "nvim", root.selPath]
        openProc.running = true
    }
    function doCopy()  { if (root.selPath === "") return; copyProc.command = ["wl-copy", root.selPath]; copyProc.running = true }
    function doTrash() { if (root.selPath === "") return; trashProc.command = ["gio", "trash", "--", root.selPath]; trashProc.running = true }
    function doRename(newName) {
        if (root.selPath === "" || !newName || newName === root.selName) { root.renaming = false; return }
        var dst = root.parentOf(root.selPath) + "/" + newName
        renameProc.command = ["mv", "--", root.selPath, dst]
        renameProc.running = true
        root.renaming = false
        root.clearSelection()
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Barre de chemin ────────────────────────────────────────────────
        Rectangle {
            width:  parent.width
            height: 34
            radius: 8
            color:  Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            Row {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Bouton remonter
                Rectangle {
                    width: 24; height: 24; radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: upHov.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰁞"; font.pixelSize: 14
                        color: root.currentPath === "/" ? Appearance.colors.dim : Appearance.colors.fg
                    }
                    HoverHandler { id: upHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.goUp() }
                }

                // Bouton home
                Rectangle {
                    width: 24; height: 24; radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: homeHov.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰋜"; font.pixelSize: 13; color: Appearance.colors.fg
                    }
                    HoverHandler { id: homeHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.enterDir(root.homePath) }
                }
            }

            Text {
                anchors {
                    left: parent.left; leftMargin: 78
                    right: parent.right; rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: root.currentPath
                color: Appearance.colors.fg
                font.family: Appearance.font.family
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
        }

        // ── Barre de recherche (récursive, fd) ──────────────────────────────
        Rectangle {
            width:  parent.width
            height: 32
            radius: 8
            color: root.searchActive
                   ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.10)
                   : Qt.rgba(1, 1, 1, 0.04)
            border.color: root.searchActive
                          ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.35)
                          : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: searchIcon
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: "󰍉"; font.pixelSize: 14
                color: root.searchActive ? Appearance.colors.accent : Appearance.colors.dim
            }

            TextInput {
                id: searchField
                anchors {
                    left: searchIcon.right; leftMargin: 8
                    right: searchClear.left; rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Appearance.colors.fg
                font.family: Appearance.font.family
                font.pixelSize: 12
                clip: true
                selectByMouse: true
                onTextChanged: { root.searchQuery = text; searchDebounce.restart() }
                Keys.onEscapePressed: searchField.text = ""

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchField.text.length === 0
                    text: "Rechercher récursivement (fd)…"
                    color: Appearance.colors.dim
                    font.family: Appearance.font.family
                    font.pixelSize: 12
                }
            }

            Text {
                anchors { right: searchClear.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                visible: root.searchActive
                text: root.searchResults.length + (root.searchResults.length >= 500 ? "+" : "")
                color: Appearance.colors.dim
                font.family: Appearance.font.family
                font.pixelSize: 10
            }

            Rectangle {
                id: searchClear
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                width: 22; height: 22; radius: 6
                visible: root.searchActive
                color: clearHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 12; color: Appearance.colors.fg }
                HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchField.text = "" }
            }
        }

        // ── Deux panneaux ──────────────────────────────────────────────────
        Row {
            width:  parent.width
            height: parent.height - 34 - 32 - 20
            spacing: 10

            // ── Liste (gauche) ─────────────────────────────────────────
            Rectangle {
                width:  Math.round(parent.width * 0.36)
                height: parent.height
                radius: 10
                color:  Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                clip: true

                ListView {
                    id: fileList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    visible: !root.searchActive
                    model: dirModel
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1

                    delegate: Item {
                        id: row
                        required property int index
                        required property string fileName
                        required property string filePath
                        required property string fileSuffix
                        required property bool   fileIsDir
                        required property var    fileSize

                        width:  fileList.width
                        height: 28

                        readonly property bool isSel: root.selPath === filePath

                        Rectangle {
                            anchors.fill: parent
                            anchors.rightMargin: 2
                            radius: 6
                            color: row.isSel
                                   ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.18)
                                   : (rowHov.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: row.isSel
                                          ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.35)
                                          : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.iconFor(row.fileIsDir, row.fileSuffix)
                                font.pixelSize: 14
                                color: row.fileIsDir ? Appearance.colors.accent
                                                     : (row.isSel ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.55))
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24 - (sizeLabel.visible ? sizeLabel.width + 8 : 0)
                                text: row.fileName
                                color: row.isSel ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.82)
                                font.family: Appearance.font.family
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: sizeLabel
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            visible: !row.fileIsDir
                            text: root.humanSize(row.fileSize)
                            color: Appearance.colors.dim
                            font.family: Appearance.font.family
                            font.pixelSize: 10
                        }

                        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                fileList.currentIndex = row.index
                                root.select(row.filePath, row.fileName, row.fileSuffix, row.fileIsDir, row.fileSize)
                            }
                            onDoubleClicked: {
                                if (row.fileIsDir) root.enterDir(row.filePath)
                                else { root.select(row.filePath, row.fileName, row.fileSuffix, false, row.fileSize); root.doOpen() }
                            }
                        }
                    }
                }

                // ── Résultats de recherche (fd) ───────────────────────────
                ListView {
                    id: searchList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    visible: root.searchActive
                    model: root.searchResults
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: srow
                        required property int index
                        required property var modelData

                        width:  searchList.width
                        height: 36
                        readonly property bool isSel: root.selPath === srow.modelData.path

                        Rectangle {
                            anchors.fill: parent
                            anchors.rightMargin: 2
                            radius: 6
                            color: srow.isSel
                                   ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.18)
                                   : (srowHov.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: srow.isSel
                                          ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.35)
                                          : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }

                        Row {
                            anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.iconFor(srow.modelData.isDir, srow.modelData.suffix)
                                font.pixelSize: 14
                                color: srow.modelData.isDir ? Appearance.colors.accent
                                                            : (srow.isSel ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.55))
                            }
                            Column {
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: srow.modelData.name
                                    color: srow.isSel ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.82)
                                    font.family: Appearance.font.family
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: root.relDisplay(srow.modelData.path)
                                    color: Appearance.colors.dim
                                    font.family: Appearance.font.family
                                    font.pixelSize: 9
                                    elide: Text.ElideLeft
                                }
                            }
                        }

                        HoverHandler { id: srowHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.select(srow.modelData.path, srow.modelData.name, srow.modelData.suffix, srow.modelData.isDir, 0)
                            onDoubleClicked: {
                                if (srow.modelData.isDir) root.enterDir(srow.modelData.path)
                                else { root.select(srow.modelData.path, srow.modelData.name, srow.modelData.suffix, false, 0); root.doOpen() }
                            }
                        }
                    }
                }

                // Dossier vide
                Text {
                    anchors.centerIn: parent
                    visible: !root.searchActive && dirModel.count === 0
                    text: "Dossier vide"
                    color: Appearance.colors.dim
                    font.family: Appearance.font.family
                    font.pixelSize: 12
                }

                // Aucun résultat de recherche
                Text {
                    anchors.centerIn: parent
                    visible: root.searchActive && root.searchResults.length === 0
                    text: "Aucun résultat"
                    color: Appearance.colors.dim
                    font.family: Appearance.font.family
                    font.pixelSize: 12
                }
            }

            // ── Aperçu (droite) ────────────────────────────────────────
            Rectangle {
                width:  parent.width - Math.round(parent.width * 0.36) - 10
                height: parent.height
                radius: 10
                color:  Qt.rgba(0, 0, 0, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                clip: true

                // En-tête de l'aperçu
                Rectangle {
                    id: prevHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: root.selPath !== "" ? 30 : 0
                    visible: root.selPath !== ""
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Text {
                        anchors { left: parent.left; leftMargin: 12; right: actionRow.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: root.selName
                        color: Appearance.colors.fg
                        font.family: Appearance.font.family
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }

                    // Boutons d'action
                    Row {
                        id: actionRow
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        visible: root.selPath !== "" && !root.renaming && !root.deleting

                        Repeater {
                            model: [
                                { ic: "󰏌", key: "open",   tip: "Ouvrir" },
                                { ic: "󰆏", key: "copy",   tip: "Copier le chemin" },
                                { ic: "󰑕", key: "rename", tip: "Renommer" },
                                { ic: "󰩺", key: "trash",  tip: "Supprimer" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 24; height: 24; radius: 6
                                readonly property bool isDanger: modelData.key === "trash"
                                color: aHov.hovered
                                       ? (isDanger ? Qt.rgba(Appearance.colors.red.r, Appearance.colors.red.g, Appearance.colors.red.b, 0.20)
                                                   : Qt.rgba(1, 1, 1, 0.12))
                                       : Qt.rgba(1, 1, 1, 0.05)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData.ic
                                    font.pixelSize: 12
                                    color: parent.isDanger && aHov.hovered ? Appearance.colors.red : Appearance.colors.fg
                                }
                                HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        switch (parent.modelData.key) {
                                            case "open":   root.doOpen(); break
                                            case "copy":   root.doCopy(); break
                                            case "rename": renameField.text = root.selName; root.renaming = true; renameField.forceActiveFocus(); renameField.selectAll(); break
                                            case "trash":  root.deleting = true; break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Corps de l'aperçu ──────────────────────────────────
                Item {
                    anchors { left: parent.left; right: parent.right; top: prevHeader.bottom; bottom: parent.bottom }

                    // Rien de sélectionné
                    Text {
                        anchors.centerIn: parent
                        visible: root.selPath === ""
                        text: "Sélectionne un fichier pour l'aperçu"
                        color: Appearance.colors.dim
                        font.family: Appearance.font.family
                        font.pixelSize: 12
                    }

                    // Dossier sélectionné
                    Text {
                        anchors.centerIn: parent
                        visible: root.selIsDir
                        text: "󰉋  " + root.selName
                        color: Appearance.colors.dim
                        font.family: Appearance.font.family
                        font.pixelSize: 13
                    }

                    // Image
                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: root.previewIsImage
                        source: root.previewImageSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    // Texte coloré (bat)
                    Flickable {
                        id: prevFlick
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: !root.selIsDir && !root.previewIsImage && root.selPath !== ""
                        contentWidth:  prevText.width
                        contentHeight: prevText.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: prevText
                            text: root.previewRich
                            textFormat: Text.RichText
                            font.family: "JetBrainsMono Nerd Font, monospace"
                            font.pixelSize: 12
                            color: Appearance.colors.fg
                            lineHeight: 1.15
                        }
                    }
                }

                // ── Confirmation de suppression ────────────────────────
                Rectangle {
                    anchors.fill: parent
                    visible: root.deleting
                    color: Qt.rgba(0, 0, 0, 0.72)
                    MouseArea { anchors.fill: parent }   // bloque les clics derrière

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        width: parent.width - 60

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Supprimer (corbeille) ?\n" + root.selName
                            color: Appearance.colors.fg
                            font.family: Appearance.font.family
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Rectangle {
                                width: 100; height: 32; radius: 8
                                color: cancelHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Annuler"; color: Appearance.colors.fg; font.pixelSize: 12; font.family: Appearance.font.family }
                                HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.deleting = false }
                            }
                            Rectangle {
                                width: 100; height: 32; radius: 8
                                color: confirmHov.hovered
                                       ? Appearance.colors.red
                                       : Qt.rgba(Appearance.colors.red.r, Appearance.colors.red.g, Appearance.colors.red.b, 0.55)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Supprimer"; color: Appearance.colors.bg; font.pixelSize: 12; font.weight: Font.Medium; font.family: Appearance.font.family }
                                HoverHandler { id: confirmHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doTrash() }
                            }
                        }
                    }
                }

                // ── Renommer ───────────────────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    visible: root.renaming
                    color: Qt.rgba(0, 0, 0, 0.72)
                    MouseArea { anchors.fill: parent }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14
                        width: parent.width - 60

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Renommer"
                            color: Appearance.colors.fg
                            font.family: Appearance.font.family
                            font.pixelSize: 13
                        }

                        Rectangle {
                            width: parent.width; height: 34; radius: 8
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Appearance.colors.accent
                            border.width: 1
                            TextInput {
                                id: renameField
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Appearance.colors.fg
                                font.family: Appearance.font.family
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onAccepted: root.doRename(text.trim())
                                Keys.onEscapePressed: root.renaming = false
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12
                            Rectangle {
                                width: 100; height: 32; radius: 8
                                color: rCancelHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Annuler"; color: Appearance.colors.fg; font.pixelSize: 12; font.family: Appearance.font.family }
                                HoverHandler { id: rCancelHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.renaming = false }
                            }
                            Rectangle {
                                width: 100; height: 32; radius: 8
                                color: rOkHov.hovered ? Appearance.colors.accent : Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.6)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Renommer"; color: Appearance.colors.bg; font.pixelSize: 12; font.weight: Font.Medium; font.family: Appearance.font.family }
                                HoverHandler { id: rOkHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doRename(renameField.text.trim()) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Raccourcis clavier ────────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        if (root.renaming || root.deleting) return
        if (event.key === Qt.Key_Backspace) { root.goUp(); event.accepted = true }
    }
}
