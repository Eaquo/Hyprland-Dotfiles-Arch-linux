#!/bin/sh
# Lance (ou relance) Quick-Bar avec son environnement, en garantissant une seule instance. Point d'entrée unique : démarrage Hyprland (Startup_Apps.lua),
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
SHELL_QML="$(readlink -f "$(dirname "$(readlink -f "$0")")/../shell.qml")"

# Une seule barre : arrête toute instance de Quick-Bar encore là (y compris celle que le gestionnaire de crash de
# Quickshell relance tout seul quand l'arrêt plante), en la cherchant par son fichier de config.
pids() { quickshell list --all 2>/dev/null | awk -v c="$SHELL_QML" '/Process ID/{p=$3} /Config path/{if ($3==c) print p}'; }
for _ in 1 2 3; do
    P=$(pids); [ -z "$P" ] && break
    kill $P 2>/dev/null; sleep 1.5
done
P=$(pids); [ -n "$P" ] && kill -9 $P 2>/dev/null

# surveillants laissés par d'anciennes versions (lancés sans --pdeathsig) : rattachés à init, ils attendaient sans fin
ps -eo pid=,ppid=,args= | awk '$2 == 1 && /nmcli monitor|inotifywait -m -q -e close_write|udevadm monitor --udev --subsystem-match=hidraw|rfkill event/ {print $1}' \
    | xargs -r kill 2>/dev/null

exec quickshell -p "$SHELL_QML" "$@"
