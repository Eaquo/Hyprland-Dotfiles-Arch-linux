#!/bin/bash
# Liste les wallpapers (images + vidéos avec vignettes) en JSON pour le picker Quickshell.
# Usage : list-wallpapers.sh [dossier images] [dossier vidéos]  (Quick-Bar : config.toml [wallpaper])
imgdir="${1:-$HOME/Pictures/wallpapers}"
viddir="${2:-$imgdir/Video}"
thumbdir="/tmp/video_thumbnails"
mkdir -p "$thumbdir"

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

printf '['
first=1

# Images (racine du dossier wallpapers, pas le sous-dossier Video)
while IFS= read -r -d '' f; do
    [ $first -eq 0 ] && printf ','; first=0
    printf '{"path":"%s","type":"image","thumb":"%s"}' "$(esc "$f")" "$(esc "$f")"
done < <(find "$imgdir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z)

# Vidéos (avec vignette générée/caché)
while IFS= read -r -d '' v; do
    thumb="$thumbdir/$(basename "$v").png"
    [ -f "$thumb" ] || ffmpegthumbnailer -i "$v" -o "$thumb" -s 360 2>/dev/null
    [ -f "$thumb" ] || continue
    [ $first -eq 0 ] && printf ','; first=0
    printf '{"path":"%s","type":"video","thumb":"%s"}' "$(esc "$v")" "$(esc "$thumb")"
done < <(find "$viddir" -type f -iname '*.mp4' -print0 | sort -z)

printf ']'
