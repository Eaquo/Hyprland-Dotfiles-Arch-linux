import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// AudioPage — Réglages › Multimédia › Audio et EQ : sortie/entrée par défaut (pactl)
// et presets EasyEffects (scripts/audio/eq_control.py).
ColumnLayout {
    id: page
    spacing: 18

    readonly property string eq: Quickshell.shellDir + "/scripts/audio/eq_control.py"
    property var sinks: []
    property var sources: []
    property string defSink: ""
    property string defSource: ""
    property var presets: []
    property string preset: ""

    function refresh() { devProc.running = false; devProc.running = true; eqProc.running = false; eqProc.running = true }
    Component.onCompleted: refresh()
    Process {
        id: devProc
        command: ["sh", "-c", "pactl --format=json list sinks; echo; pactl --format=json list sources; echo; pactl get-default-sink; pactl get-default-source"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").filter(x => x.trim() !== "")
                try {
                    page.sinks = JSON.parse(l[0]).filter(s => s.name !== "easyeffects_sink")
                    page.sources = JSON.parse(l[1]).filter(s => s.name.indexOf(".monitor") < 0 && s.name !== "easyeffects_source")
                    page.defSink = l[2] || ""; page.defSource = l[3] || ""
                } catch (e) {}
            }
        }
    }
    Process {
        id: eqProc
        command: ["sh", "-c", "python3 \"$1\" list; echo; python3 \"$1\" get", "_", page.eq]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").filter(x => x.trim() !== "")
                try { page.presets = JSON.parse(l[0]).presets.filter(p => p !== "quickbar_eq"); page.preset = JSON.parse(l[1]).preset } catch (e) {}
            }
        }
    }
    function run(cmd) { Quickshell.execDetached(cmd); again.restart() }
    Timer { id: again; interval: 600; onTriggered: page.refresh() }

    PageHeader { title: "Audio et EQ"; sub: "pactl · EasyEffects (scripts/audio/eq_control.py)" }

    SetCard {
        title: "Sortie"
        Repeater {
            model: page.sinks
            delegate: Device { required property var modelData; dev: modelData; current: page.defSink
                               onPick: page.run(["pactl", "set-default-sink", modelData.name]) }
        }
        Text { visible: page.sinks.length === 0; text: "Lecture des périphériques…"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
    }
    SetCard {
        title: "Micro"
        Repeater {
            model: page.sources
            delegate: Device { required property var modelData; dev: modelData; current: page.defSource; icon: "󰍬"
                               onPick: page.run(["pactl", "set-default-source", modelData.name]) }
        }
    }

    SetCard {
        title: "Égaliseur"
        SetRow {
            title: "Preset actif"; desc: page.preset !== "" ? page.preset : "—"; wide: true
            Flow {
                width: parent ? parent.width : 600
                spacing: 6
                Repeater {
                    model: page.presets
                    delegate: SetButton {
                        required property string modelData
                        label: modelData; active: page.preset === modelData
                        onTap: page.run(["python3", page.eq, "load_preset", modelData])
                    }
                }
            }
        }
        SetRow {
            title: "Preset en jeu"; desc: "Mode jeu : auto = Bose-FPS sur le Bose, KZ-FPS sinon"
            SetButton { label: "󰊴  Mode jeu"; onTap: Popups.settingsPage = "game" }
        }
        SetRow {
            title: "Applications"
            RowLayout {
                spacing: 8
                SetButton { label: "EasyEffects"; onTap: Quickshell.execDetached(["easyeffects"]) }
                SetButton { label: "pavucontrol"; onTap: Quickshell.execDetached(["pavucontrol"]) }
            }
        }
    }

    component Device: SetRow {
        id: dv
        property var dev: ({})
        property string current: ""
        property string icon: "󰓃"
        signal pick()
        title: icon + "  " + (dev.description || dev.name)
        desc: dev.name === current ? "par défaut" : ""
        SetButton { label: dv.dev.name === dv.current ? "✓ Par défaut" : "Utiliser"; active: dv.dev.name === dv.current; onTap: if (dv.dev.name !== dv.current) dv.pick() }
    }
}
