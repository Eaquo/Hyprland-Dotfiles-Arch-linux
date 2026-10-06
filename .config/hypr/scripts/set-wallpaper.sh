#!/bin/bash
# Applique un wallpaper STATIQUE sans awww.
# Met à jour les marqueurs (symlink rofi + copie effects) puis régénère wallust.
# Quickshell (Quick-Bar) rend l'image et réagit à wal.json.
#
# Usage: set-wallpaper.sh /chemin/vers/image.jpg

wp="$1"
[ -f "$wp" ] || { echo "wallpaper introuvable: $wp" >&2; exit 1; }

# Marqueur symlink (lu par Quickshell + rofi)
ln -sf "$wp" "$HOME/.config/rofi/.current_wallpaper"

# Copie pour les "wallpaper effects" / SDDM
mkdir -p "$HOME/.config/hypr/wallpaper_effects"
cp -f "$wp" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# Régénère la palette (skip séquences terminal) → wal.json change → Quickshell recharge
{ wallust run "$wp" -s >/dev/null 2>&1; pkill -USR1 -x kitty; bash "$HOME/.config/hypr/scripts/Refresh.sh"; } >/dev/null 2>&1 &  # USR1 = kitty recharge couleurs + shader ; Refresh = GTK/swaync/rofi/OpenRGB…

echo "$wp"
