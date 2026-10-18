//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Tous les modules partagés sont importés ici : Quickshell n'enregistre un module qu'une fois
// importé par un fichier déjà chargé ; sans ça, une page chargée plus tard (Grid, Game…)
// échoue avec « module … is not installed ».
import qs.bar
import qs.components
import qs.components.stats
import qs.core
import qs.core.functions
import qs.services
import qs.services.system
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
    WallpaperPicker {}
    WallpaperCinema {}
    SessionPanel {}
    // génère Quick-Bar/hypr/quickbar.lua (raccourcis) et s'assure que hyprland.lua le charge
    readonly property var _keybinds: KeybindService
}
