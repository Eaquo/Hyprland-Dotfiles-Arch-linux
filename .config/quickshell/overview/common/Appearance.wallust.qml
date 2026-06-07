pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Common

QtObject {
    id: root

    property FileView _file: FileView {
        path: Common.Config.options.appearance.wallustPath
              .replace("~", Quickshell.env("HOME"))
        watchChanges: true
        onFileChanged: reload()          // ← recharge le fichier depuis le disque
        onLoaded: root._data = root._parse()  // ← parse après chaque chargement
    }

    function _parse() {
        try {
            const raw = _file.text()
            if (!raw || raw.length === 0) return {}
            return JSON.parse(raw)
        } catch(e) {
            console.warn("[Wallust] Erreur parsing wal.json :", e)
            return {}
        }
    }

    property var _data: ({})
    Component.onCompleted: _data = _parse()

    property var _colors:  _data.colors  ?? {}
    property var _special: _data.special ?? {}

    readonly property bool darkmode: true

    property color m3background:              _special["background"]  ?? "#161217"
    property color m3onBackground:            _special["foreground"]  ?? "#EAE0E7"
    property color m3surface:                 _special["background"]  ?? "#161217"
    property color m3onSurface:               _special["foreground"]  ?? "#EAE0E7"
    property color m3inverseSurface:          _special["foreground"]  ?? "#EAE0E7"
    property color m3inverseOnSurface:        _special["background"]  ?? "#342F34"
    property color m3primary:                 _colors["color4"]  ?? "#E5B6F2"
    property color m3onPrimary:               _colors["color0"]  ?? "#452152"
    property color m3primaryContainer:        _colors["color12"] ?? "#5D386A"
    property color m3onPrimaryContainer:      _colors["color4"]  ?? "#F9D8FF"
    property color m3secondary:               _colors["color5"]  ?? "#D5C0D7"
    property color m3onSecondary:             _colors["color0"]  ?? "#392C3D"
    property color m3secondaryContainer:      _colors["color13"] ?? "#534457"
    property color m3onSecondaryContainer:    _colors["color5"]  ?? "#F2DCF3"
    property color m3surfaceVariant:          _colors["color8"]  ?? "#4C444D"
    property color m3onSurfaceVariant:        _colors["color7"]  ?? "#CFC3CD"
    property color m3surfaceContainerLow:     _colors["color0"]  ?? "#1F1A1F"
    property color m3surfaceContainer:        _colors["color8"]  ?? "#231E23"
    property color m3surfaceContainerHigh:    _colors["color0"]  ?? "#2D282E"
    property color m3surfaceContainerHighest: _colors["color8"]  ?? "#383339"
    property color m3outline:                 _colors["color8"]  ?? "#988E97"
    property color m3outlineVariant:          _colors["color0"]  ?? "#4C444D"
    property color m3shadow:                  "#000000"
}