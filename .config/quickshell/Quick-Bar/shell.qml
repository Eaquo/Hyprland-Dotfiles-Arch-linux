//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import qs.bar
import qs.core.functions
import qs.panels
import qs.wallpaper


import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Wallpaper {}
    TouchPanel {}
    GameBreakBar {}
    Bar {}
    CalendarWindow {}
    EqPopup {}
    SysTrayPopup {}
    MediaPlayerPopup {}
    Dashboard {}
    SpotifyPanel {}
    SettingsPanel {}
}
