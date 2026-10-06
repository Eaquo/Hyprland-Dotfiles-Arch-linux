#!/bin/bash
# Applique un mode RGB (OpenRGB) de façon détachée. Chemin auto (dossier du script).
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/script"
MODE="$1"
[ -z "$MODE" ] && { echo "Usage: $0 <mode>"; exit 1; }
pkill -f 'OpenRGB_Controller.py' 2>/dev/null
pkill -f 'OpenWal.py' 2>/dev/null
sleep 0.3
setsid python3 "$SCRIPT_PATH/OpenRGB_Controller.py" "$MODE" </dev/null >/dev/null 2>&1 &
disown
exit 0
