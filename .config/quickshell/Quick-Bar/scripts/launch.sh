#!/bin/sh
# Lance Quick-Bar avec son environnement. Point d'entrée unique : démarrage Hyprland (Startup_Apps.lua),
# relance après un jeu (GameScripts), « Relancer Quick-Bar » (bar/SysStats.qml).
#   MALLOC_MMAP_THRESHOLD_ : les gros tampons (wallpapers 5K…) sont rendus au système une fois libérés (~80 Mo)
#   QML_IMPORT_PATH        : qmltermwidget y cherche QMLTermWidget/color-schemes → schéma du terminal aux
#                            couleurs de la palette (pages/terminal/TerminalTab.qml l'écrit)
export MALLOC_MMAP_THRESHOLD_=131072
TERM_QML="${XDG_CACHE_HOME:-$HOME/.cache}/quickbar/qml"
mkdir -p "$TERM_QML/QMLTermWidget/color-schemes"
# un chemin d'import ajouté remplace les dossiers du module : sans ses tables de clavier, les flèches,
# Échap, F1… ne sont plus traduites → lien vers celles du paquet
for d in /usr/lib/qt6/qml /usr/lib/qt/qml; do
    [ -d "$d/QMLTermWidget/kb-layouts" ] && { ln -sfn "$d/QMLTermWidget/kb-layouts" "$TERM_QML/QMLTermWidget/kb-layouts"; break; }
done
export QML_IMPORT_PATH="$TERM_QML${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
exec quickshell -p "$(readlink -f "$(dirname "$(readlink -f "$0")")/../shell.qml")" "$@"
