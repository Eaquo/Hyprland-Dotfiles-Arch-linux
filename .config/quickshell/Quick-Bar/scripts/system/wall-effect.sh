#!/bin/sh
# wall-effect.sh <effet> — effet ImageMagick sur le fond d'écran (remplace UserScripts/WallpaperEffects.sh, qui passait
# par swww + rofi). Part toujours de l'image d'origine (notée par ~/.config/hypr/scripts/set-wallpaper.sh dans
# wallpaper_effects/.wallpaper_source) : les effets ne se cumulent pas. Recolore wallust depuis l'image modifiée ;
# Quick-Bar suit le symlink du fond (wallpaper/Wallpaper.qml). « none » remet l'original.
#   effets : none bw blur sepia oil charcoal poster vignette negate solarize edge emboss
set -e
fx="${1:?effet manquant}"
dir="$HOME/.config/hypr/wallpaper_effects"
src="$(cat "$dir/.wallpaper_source" 2>/dev/null || true)"
[ -f "$src" ] || src="$dir/.wallpaper_current"                  # ancien fond sans source notée : la copie
[ -f "$src" ] || { echo "aucun fond d'origine" >&2; exit 1; }

if [ "$fx" = none ]; then
    exec "$HOME/.config/hypr/scripts/set-wallpaper.sh" "$src"
fi

case "$fx" in
    bw)       op="-colorspace gray -sigmoidal-contrast 10,40%" ;;
    blur)     op="-blur 0x12" ;;
    sepia)    op="-sepia-tone 65%" ;;
    oil)      op="-paint 4" ;;
    charcoal) op="-charcoal 0x5" ;;
    poster)   op="-posterize 4" ;;
    vignette) op="-background black -vignette 0x3" ;;
    negate)   op="-negate" ;;
    solarize) op="-solarize 80%" ;;
    edge)     op="-edge 1" ;;
    emboss)   op="-emboss 0x5" ;;
    *) echo "effet inconnu : $fx" >&2; exit 1 ;;
esac

out="$HOME/.cache/quickbar/wall-effect-$fx.png"
mkdir -p "${out%/*}"
# ponytail: réduit à 3840 px de large avant l'effet (5K/8K → quelques secondes de moins, invisible à l'écran)
# shellcheck disable=SC2086
magick "$src" -resize '3840x>' $op "$out"
ln -sf "$out" "$HOME/.config/rofi/.current_wallpaper"
wallust run "$out" -s >/dev/null 2>&1 || true
pkill -USR1 -x kitty 2>/dev/null || true
bash "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 &
echo "$out"
