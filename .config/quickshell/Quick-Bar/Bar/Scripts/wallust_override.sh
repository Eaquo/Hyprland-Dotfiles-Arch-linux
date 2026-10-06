#!/bin/bash
# Surcharge manuelle des couleurs wallust (onglet Wallust du TouchPanel).
#
#   apply '<json pywal>'  → sauve la palette de base (1re fois), applique la
#                           palette modifiée via `wallust cs` (tous les templates)
#   reset                 → réapplique la palette de base, oublie la surcharge
#   status                → "override" si une surcharge est active, sinon "base"
#
# Un nouveau `wallust run` (changement de wallpaper) écrase la surcharge : on le
# détecte (wal.json ≠ override.json) et on jette la base devenue périmée.

D="$HOME/.cache/quickbar-wallust"
WAL="$HOME/.cache/wal/wal.json"
mkdir -p "$D"

colors_of() { jq -c '[.special, .colors] | walk(if type == "string" then ascii_downcase else . end)' "$1" 2>/dev/null; }

# Surcharge encore en place ? Sinon wallust a tourné entre-temps → état propre.
if [ -f "$D/override.json" ] && [ "$(colors_of "$D/override.json")" != "$(colors_of "$WAL")" ]; then
    rm -f "$D/base.json" "$D/override.json"
fi

apply_scheme() {
    wallust cs -f pywal -s -q "$1" >/dev/null 2>&1
    pkill -USR1 -x kitty   # kitty recharge ses couleurs (comme set-wallpaper.sh)
    # Recharge le reste comme après un changement de wallpaper (thème GTK,
    # swaync, rofi, OpenRGB, Windsurf…). Détaché : npm build + sleeps ≈ quelques s.
    setsid -f bash "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1
}

case "$1" in
    apply)
        [ -f "$D/base.json" ] || cp "$WAL" "$D/base.json"
        printf '%s' "$2" > "$D/override.json"
        apply_scheme "$D/override.json"
        ;;
    reset)
        [ -f "$D/base.json" ] && apply_scheme "$D/base.json"
        rm -f "$D/base.json" "$D/override.json"
        ;;
    status)
        [ -f "$D/override.json" ] && echo override || echo base
        ;;
esac
