#!/bin/bash
# Applique un wallpaper VIDÉO via gslapper, en gardant la palette wallust et les
# marqueurs statiques synchronisés — miroir de set-wallpaper.sh, côté vidéo.
#
# Reprend l'idée du script rofi original : on extrait une vignette d'un frame de
# la vidéo, on la donne à wallust (→ wal.json → Quickshell recharge les couleurs)
# et on l'utilise comme image statique (avatar profil, fond du touch panel).
#
# Usage: set-video-wallpaper.sh <monitor> /chemin/vers/video.mp4

mon="$1"
vid="$2"
[ -f "$vid" ] || { echo "video introuvable: $vid" >&2; exit 1; }

thumb="$HOME/.curr_wall_static.jpg"

# 1. Vignette d'un frame → sert à wallust + fond touch + avatar profil
rm -f "$thumb"
ffmpegthumbnailer -i "$vid" -o "$thumb" -s 1920 -q 10 2>/dev/null

# 2. Marqueurs identiques à set-wallpaper.sh (pointant sur la vignette)
ln -sf "$thumb" "$HOME/.config/rofi/.current_wallpaper"
mkdir -p "$HOME/.config/hypr/wallpaper_effects"
cp -f "$thumb" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# 3. Palette wallust depuis la vignette (skip séquences terminal)
{ wallust run "$thumb" -s >/dev/null 2>&1; pkill -USR1 -x kitty; bash "$HOME/.config/hypr/scripts/Refresh.sh"; } >/dev/null 2>&1 &  # + recharge kitty/GTK/swaync/rofi/OpenRGB…

# 4. gslapper prend le fond — tue l'ancien gslapper + awww-daemon d'abord
pkill -x gslapper 2>/dev/null
if pgrep -x awww-daemon >/dev/null; then
    pkill -x awww-daemon 2>/dev/null
    sleep 0.3
fi
setsid -f gslapper -v -o "loop stretch" "$mon" "$vid"

echo "$vid"
