#!/bin/bash
# Met à jour la couleur d'accent Steam Material-Theme depuis wallust
# Appelé après chaque changement de wallpaper

COLORS_JSON="$HOME/.cache/wal/wal.json"
MILLENNIUM_CONFIG="$HOME/.config/millennium/config.json"

# Vérifie que les fichiers existent
if [ ! -f "$COLORS_JSON" ]; then
    echo "WallustSteam: wal.json introuvable"
    exit 1
fi

if [ ! -f "$MILLENNIUM_CONFIG" ]; then
    echo "WallustSteam: config.json Millennium introuvable"
    exit 1
fi

# Récupère color12 depuis wallust
COLOR=$(python3 -c "
import json, sys
with open('$COLORS_JSON') as f:
    c = json.load(f)
print(c['colors']['color12'])
")

if [ -z "$COLOR" ]; then
    echo "WallustSteam: couleur introuvable"
    exit 1
fi

echo "WallustSteam: application de $COLOR comme accent Steam..."

# Met à jour le config.json Millennium
jq --arg color "$COLOR" \
    '.themes.themeColors["Material-Theme"]["--custom-accent-color"] = $color' \
    "$MILLENNIUM_CONFIG" > /tmp/millennium-tmp.json && \
    mv /tmp/millennium-tmp.json "$MILLENNIUM_CONFIG"

echo "WallustSteam: ✓ couleur d'accent mise à jour → $COLOR"
