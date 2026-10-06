#!/bin/bash
# Démon RGB (OpenRGB_Controller_Watch.py) — un seul point d'entrée.
#   ensure  → le lance s'il ne tourne pas déjà (démarrage de Quick-Bar)
#   restart → tue watcher + contrôleurs puis relance (Refresh.sh : nouvelles couleurs)
# Tuer aussi les contrôleurs évite les doublons : le watcher ne tue que son
# propre enfant, un contrôleur orphelin continuerait sinon en parallèle.

DIR="$(cd "$(dirname "$0")" && pwd)/script"

start() { setsid -f python3 "$DIR/OpenRGB_Controller_Watch.py" </dev/null >/dev/null 2>&1; }

case "$1" in
    ensure)
        pgrep -f OpenRGB_Controller_Watch.py >/dev/null || start
        ;;
    restart)
        pkill -f OpenRGB_Controller_Watch.py
        pkill -f 'OpenRGB_Controller.py'
        pkill -f 'OpenWal.py'
        sleep 0.3
        start
        ;;
    *)
        echo "Usage: $0 ensure|restart" >&2; exit 1
        ;;
esac
