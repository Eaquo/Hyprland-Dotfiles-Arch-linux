import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// DataPage — Réglages › Avancé › Données : sauvegarde / restauration de config.toml + user_data,
// réinitialisation (avec copie de secours). Les secrets (.discord_token…) ne sont jamais exportés.
ColumnLayout {
    id: page
    spacing: 18

    readonly property string dir: Quickshell.shellDir
    property string msg: ""
    property string armed: ""            // action qui attend sa confirmation
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = "" }
    function confirm(a) { if (armed === a) { armed = ""; return true } armed = a; disarm.restart(); return false }

    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: page.msg = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") page.msg = "⚠ " + text.trim() }
    }
    function sh(script, ...args) { proc.command = ["sh", "-c", script, "_"].concat(args); proc.running = false; proc.running = true }

    PageHeader { title: "Données"; sub: "config.toml + user_data/ (" + page.dir + ")" }

    SetCard {
        title: "Sauvegarde"
        SetRow {
            title: "Exporter"; desc: "archive dans ~/ : config.toml et user_data/ (sans les jetons secrets)"
            SetButton { label: "󰆓  Exporter"; primary: true
                        onTap: page.sh("f=\"$HOME/quickbar-$(date +%Y%m%d-%H%M).tar.gz\"; tar -czf \"$f\" -C \"$1\" config.toml user_data && echo \"Exporté : $f\"", page.dir) }
        }
        SetRow {
            title: "Importer"; desc: "remplace config.toml et user_data/ (copie de secours faite avant)"
            SetButton { label: page.armed === "import" ? "Confirmer ?" : "󰋺  Importer…"; active: page.armed === "import"
                        onTap: if (page.confirm("import")) page.sh(
                            "f=$(zenity --file-selection --title='Sauvegarde Quick-Bar' --file-filter='*.tar.gz' 2>/dev/null || kdialog --getopenfilename ~ '*.tar.gz') || exit 0; "
                            + "tar -tzf \"$f\" | grep -qx config.toml || { echo '⚠ archive invalide' ; exit 0; }; "
                            + "b=\"$1/backup-$(date +%Y%m%d-%H%M%S)\"; mkdir -p \"$b\" && cp -a \"$1/config.toml\" \"$1/user_data\" \"$b\"/ && "
                            + "tar -xzf \"$f\" -C \"$1\" config.toml user_data && echo \"Importé (ancienne version : $b)\"", page.dir) }
        }
    }

    SetCard {
        title: "Réinitialiser"
        SetRow {
            title: "Réglages (config.toml)"; desc: "revient aux valeurs par défaut ; l'ancien fichier est gardé en config.toml.bak"
            SetButton { label: page.armed === "reset" ? "Confirmer ?" : "󰑓  Réinitialiser"; active: page.armed === "reset"
                        onTap: if (page.confirm("reset")) page.sh(
                            "cp -a \"$1/config.toml\" \"$1/config.toml.bak\" && printf '%s\\n' '# Quick-Bar — réglages (Réglages : SUPER+F1).' '# Une valeur absente = valeur par défaut.' > \"$1/config.toml\" && echo 'Réglages réinitialisés (copie : config.toml.bak)'", page.dir) }
        }
        SetRow {
            title: "Restaurer config.toml.bak"; desc: "annule la dernière réinitialisation"
            SetButton { label: "󰕌  Restaurer"
                        onTap: page.sh("[ -f \"$1/config.toml.bak\" ] && cp -a \"$1/config.toml.bak\" \"$1/config.toml\" && echo 'config.toml restauré' || echo 'Aucune copie'", page.dir) }
        }
    }

    SetCard {
        title: "Fichiers"
        SetRow {
            title: "Ouvrir le dossier"; desc: page.dir
            RowLayout {
                spacing: 8
                SetButton { label: "󰉋  Dossier"; onTap: Quickshell.execDetached(["xdg-open", page.dir]) }
                SetButton { label: "󰈮  config.toml"; onTap: Quickshell.execDetached(Config.term("config.toml", [String(Config.get("general.editor", "nvim")), page.dir + "/config.toml"])) }
            }
        }
    }

    Text {
        visible: page.msg !== ""
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: page.msg
        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2
        color: page.msg.startsWith("⚠") ? Appearance.colors.color12 : Appearance.colors.accent
    }
}
