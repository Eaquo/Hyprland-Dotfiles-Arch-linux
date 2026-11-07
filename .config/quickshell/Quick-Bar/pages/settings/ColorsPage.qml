import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// ColorsPage — Réglages › Apparence › Couleurs : source de la palette ([theme]).
// Wallust et Matugen sont exclusifs ; Appearance suit `theme.palette` en direct.
ColumnLayout {
    id: page
    spacing: 18

    readonly property string source: Appearance.paletteSource
    function pick(src) { Config.set("theme.palette", src) }

    PageHeader { title: "Couleurs"; sub: "[theme] palette · wallust_path · matugen_path dans config.toml" }

    SetCard {
        title: "Source des couleurs"
        SourceRow {
            key: "wallust"
            title: "Palette Wallust"
            desc: "Couleurs générées par wallust depuis le fond d'écran (Hyprland, kitty et rofi la suivent aussi)."
            pathKey: "theme.wallust_path"; defaultPath: "~/.cache/wal/wal.json"
        }
        SourceRow {
            key: "matugen"
            title: "Palette Matugen"
            desc: "Couleurs Material You générées par matugen — exclusif avec Wallust. Quick-Bar relance matugen à chaque changement de fond d'écran."
            pathKey: "theme.matugen_path"; defaultPath: "~/.cache/matugen/quickbar_colors.json"
        }
    }

    // ── Palette wallust 4 : d'après le fond (palette, style, contraste, saturation) ou thème fixe, avec aperçu ──
    // scripts/system/wallust-palette.sh : « preview » calcule sans rien écrire, « apply » écrit wallust.toml / applique.
    SetCard {
        id: wcard
        title: "Palette Wallust"
        visible: page.source === "wallust"             // options de wallust seulement quand il est la source
        readonly property string script: Quickshell.shellDir + "/scripts/system/wallust-palette.sh"
        property string mode: "fond"
        property string palette: "kmeans"
        property string style: "dark"
        property bool contrast: true
        property int saturation: 0
        property string theme: ""
        property string search: ""
        property var themes: []
        property var prev: null
        property bool busy: false
        function args() { return mode === "fond" ? ["fond", palette, style, contrast ? "1" : "0", String(saturation)] : ["theme", theme] }
        function refreshPreview() { if (mode === "theme" && theme === "") { prev = null; return } previewT.restart() }
        onModeChanged: refreshPreview(); onPaletteChanged: refreshPreview(); onStyleChanged: refreshPreview()
        onContrastChanged: refreshPreview(); onSaturationChanged: refreshPreview(); onThemeChanged: refreshPreview()
        Timer { id: previewT; interval: 250; onTriggered: { prevProc.command = [wcard.script, "preview"].concat(wcard.args()); prevProc.running = false; prevProc.running = true } }
        Process { id: prevProc; stdout: StdioCollector { onStreamFinished: { try { wcard.prev = JSON.parse(text) } catch (e) { wcard.prev = null } } } }
        // réglages actuels de wallust.toml, et liste des thèmes intégrés + nos palettes
        Process {
            running: true
            command: ["python3", "-I", "-c", "import tomllib,json,os; d=tomllib.load(open(os.path.expanduser('~/.config/wallust/wallust.toml'),'rb')); print(json.dumps({k:d.get(k) for k in ('palette','style','check_contrast','saturation')}))"]
            stdout: StdioCollector { onStreamFinished: { try { const d = JSON.parse(text); wcard.palette = d.palette || "kmeans"; wcard.style = d.style || "dark"
                                                              wcard.contrast = d.check_contrast !== false; wcard.saturation = Number(d.saturation || 0) } catch (e) {} wcard.refreshPreview() } }
        }
        Process {
            running: true
            command: ["sh", "-c", "ls ~/.config/wallust/colorschemes/*.json 2>/dev/null | xargs -rn1 basename | sed 's/\\.json$//'; wallust theme list 2>/dev/null | sed -n 's/^- //p'"]
            stdout: StdioCollector { onStreamFinished: wcard.themes = text.split("\n").filter(l => l.trim() !== "") }
        }
        readonly property var matches: { const q = search.toLowerCase(); return themes.filter(t => q === "" || t.toLowerCase().includes(q)).slice(0, 24) }

        SetRow {
            title: "Couleurs"
            SetSeg { options: [["fond", "D'après le fond"], ["theme", "Thème fixe"]]; current: wcard.mode; onPicked: (v) => wcard.mode = v }
        }
        // ── d'après le fond ──
        SetRow {
            visible: wcard.mode === "fond"; title: "Palette"
            desc: wcard.palette === "kmeans" ? "la plus fidèle à l'image (pas de style clair)" : wcard.palette === "salience" ? "les couleurs qui attirent l'œil" : "couleurs de terminal classiques, teintées par le fond"
            SetSeg { options: [["kmeans", "kmeans"], ["salience", "salience"], ["ansi", "ansi"]]; current: wcard.palette; onPicked: (v) => wcard.palette = v }
        }
        SetRow {
            visible: wcard.mode === "fond"; title: "Style"
            desc: wcard.palette === "kmeans" && wcard.style === "light" ? "kmeans ignore le clair (wallust 4 alpha) : préfère salience" : ""
            SetSeg { options: [["dark", "Sombre"], ["light", "Clair"]]; current: wcard.style; onPicked: (v) => wcard.style = v }
        }
        SetRow {
            visible: wcard.mode === "fond"; title: "Contraste garanti"; desc: "rend les couleurs lisibles sur le fond"
            SetSwitch { on: wcard.contrast; onToggled: wcard.contrast = !wcard.contrast }
        }
        SetRow {
            visible: wcard.mode === "fond"; title: "Saturation"; desc: "0 = celle de l'image"
            SetSlider { implicitWidth: 260; from: 0; to: 100; step: 5; suffix: " %"; value: wcard.saturation; onMoved: (v) => wcard.saturation = v }
        }
        // ── thème fixe ──
        SetRow {
            visible: wcard.mode === "theme"; title: "Chercher un thème"; desc: wcard.themes.length + " thèmes (nos palettes en tête)"
            SetInput { implicitWidth: 260; placeholder: "gruvbox, nord, kanagawa…"; text: wcard.search; onCommitted: (t) => wcard.search = t; onTextChanged: wcard.search = text }
        }
        Flow {
            visible: wcard.mode === "theme"
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: wcard.matches
                delegate: SetButton { required property string modelData; label: modelData; active: wcard.theme === modelData; onTap: wcard.theme = modelData }
            }
        }
        // ── aperçu : fond, texte, 16 couleurs, et un bout de code ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 132
            radius: 12
            color: wcard.prev ? wcard.prev.bg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Behavior on color { ColorAnimation { duration: Appearance.dur(250) } }
            Text { anchors.centerIn: parent; visible: !wcard.prev; text: wcard.mode === "theme" ? "choisis un thème pour l'aperçu" : "calcul de l'aperçu…"
                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.dim }
            Column {
                visible: !!wcard.prev
                x: 14; y: 12; spacing: 8
                Row {
                    spacing: 4
                    Repeater { model: wcard.prev ? wcard.prev.c : []
                        delegate: Rectangle { required property var modelData; width: 22; height: 22; radius: 6; color: modelData
                                              border.width: 1; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.35) } }
                }
                Text { textFormat: Text.RichText; font.family: "JetBrains Mono"; font.pixelSize: 14
                       text: !wcard.prev ? "" : '<span style="color:' + wcard.prev.c[8] + '"># commentaire</span><br>'
                             + '<span style="color:' + wcard.prev.c[5] + '">def </span><span style="color:' + wcard.prev.c[4] + '">mode</span>'
                             + '<span style="color:' + wcard.prev.fg + '">(nom, temp=</span><span style="color:' + wcard.prev.c[2] + '">4500</span>'
                             + '<span style="color:' + wcard.prev.fg + '">):</span><br><span style="color:' + wcard.prev.fg + '">&nbsp;&nbsp;&nbsp;&nbsp;return </span>'
                             + '<span style="color:' + wcard.prev.c[3] + '">"~/.cache"</span>' }
            }
        }
        SetRow {
            title: wcard.busy ? "Application…" : "Appliquer à tout le système"
            desc: wcard.mode === "theme" ? "thème fixe jusqu'au prochain changement de fond" : "enregistré dans wallust.toml, recolore depuis le fond actuel"
            SetButton {
                label: "󰏘  Appliquer"; primary: true
                onTap: { if (wcard.mode === "theme" && wcard.theme === "") return
                         wcard.busy = true; Quickshell.execDetached([wcard.script, "apply"].concat(wcard.args())); busyT.restart() }
            }
        }
        Timer { id: busyT; interval: 4000; onTriggered: wcard.busy = false }
    }

    SetCard {
        title: "Matugen"
        visible: page.source === "matugen"             // options de matugen seulement quand il est la source
        SetRow {
            title: "Couleur source"
            desc: "Quand l'image a plusieurs couleurs dominantes, laquelle garder."
            SetSeg {
                options: [["saturation", "Saturée"], ["value", "Lumineuse"], ["darkness", "Sombre"], ["less-saturation", "Douce"]]
                current: String(Config.get("theme.matugen_prefer", "saturation"))
                onPicked: (v) => { Config.set("theme.matugen_prefer", v); regen.restart() }
            }
        }
        SetRow {
            title: "Mode"
            SetSeg {
                options: [["dark", "Sombre"], ["light", "Clair"], ["smart", "Auto"]]
                current: String(Config.get("theme.matugen_mode", "dark"))
                onPicked: (v) => { Config.set("theme.matugen_mode", v); regen.restart() }
            }
        }
        SetRow {
            title: "Type de palette"
            desc: "la façon dont matugen décline la couleur source"
            SetDropdown {
                options: [["scheme-tonal-spot", "Tonal (par défaut)"], ["scheme-content", "Contenu (fidèle à l'image)"],
                          ["scheme-fidelity", "Fidélité (couleur exacte)"], ["scheme-vibrant", "Vif"],
                          ["scheme-expressive", "Expressif"], ["scheme-fruit-salad", "Salade de fruits"],
                          ["scheme-rainbow", "Arc-en-ciel"], ["scheme-neutral", "Neutre"],
                          ["scheme-monochrome", "Monochrome"], ["scheme-smart", "Auto"]]
                current: String(Config.get("theme.matugen_type", "scheme-tonal-spot"))
                onPicked: (v) => { Config.set("theme.matugen_type", v === "scheme-tonal-spot" ? null : v); regen.restart() }
            }
        }
        SetRow {
            title: "Contraste"
            desc: "-1 = doux · 0 = normal · 1 = fort"
            SetSlider { implicitWidth: 260; from: -1; to: 1; step: 0.1; decimals: 1; value: Number(Config.get("theme.matugen_contrast", 0))
                        onMoved: (v) => { Config.set("theme.matugen_contrast", Math.abs(v) < 0.05 ? null : Math.round(v * 10) / 10); regen.restart() } }
        }
        SetRow {
            title: "Régénérer maintenant"
            desc: "Relance matugen sur le fond d'écran actuel."
            SetButton { label: "󰑓  Régénérer"; onTap: Appearance.regenerateMatugen() }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Modèle : ~/.config/matugen/templates/quickbar.json (même format que wallust). Hyprland, kitty et rofi restent sur wallust tant que leurs propres modèles matugen ne sont pas ajoutés."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
    }
    // laisse Config écrire la préférence avant de relancer matugen
    Timer { id: regen; interval: 450; onTriggered: Appearance.regenerateMatugen() }

    // ── Une source de palette : interrupteur exclusif + chemin + aperçu des couleurs ──
    component SourceRow: Rectangle {
        id: sr
        property string key: ""
        property string title: ""
        property string desc: ""
        property string pathKey: ""
        property string defaultPath: ""
        readonly property bool on: page.source === key
        readonly property string path: String(Config.get(pathKey, defaultPath))
        property var pal: []
        Layout.fillWidth: true
        implicitHeight: srCol.implicitHeight + 24
        radius: 12
        color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.08) : "transparent"
        border.width: 1; border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
        Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }

        FileView {
            path: "file://" + (sr.path.startsWith("~") ? Quickshell.env("HOME") + sr.path.slice(1) : sr.path)
            watchChanges: true
            onFileChanged: reload()
            onLoaded: { try { const j = JSON.parse(text()); sr.pal = [j.special.background, j.special.foreground]
                              .concat(Array.from({ length: 16 }, (_, i) => j.colors["color" + i])) } catch (e) { sr.pal = [] } }
            onLoadFailed: sr.pal = []
        }

        ColumnLayout {
            id: srCol
            x: 14; y: 12; width: parent.width - 28
            spacing: 10
            SetRow {
                title: sr.title; desc: sr.desc
                SetSwitch { on: sr.on; onToggled: page.pick(sr.on ? (sr.key === "wallust" ? "matugen" : "wallust") : sr.key) }
            }
            SetInput {
                Layout.fillWidth: true
                text: sr.path
                placeholder: sr.defaultPath
                onCommitted: (t) => Config.set(sr.pathKey, t === "" || t === sr.defaultPath ? null : t)
            }
            Row {
                spacing: 4
                Repeater {
                    model: sr.pal
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 20; height: 20; radius: 6
                        color: modelData || "transparent"
                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    }
                }
                Text { visible: sr.pal.length === 0; text: "fichier introuvable ou illisible"
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.color12 }
            }
        }
    }
}
