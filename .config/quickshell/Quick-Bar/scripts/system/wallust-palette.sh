#!/bin/bash
# wallust-palette.sh — sélecteur de palettes de Réglages › Couleurs (pages/settings/ColorsPage.qml), wallust 4.
#   preview fond <palette> <style> <contraste 0|1> <saturation 0-100>   aperçu calculé depuis le fond (JSON sur stdout)
#   preview theme <nom>                                                  aperçu d'un thème intégré ou d'une palette maison
#   apply fond <palette> <style> <contraste> <saturation>                écrit wallust.toml puis recolore tout
#   apply theme <nom>                                                    applique un thème fixe (jusqu'au prochain fond)
# L'aperçu passe par une config temporaire à un seul modèle : rien n'est écrit dans tes vrais fichiers.
set -eu
QB="$(cd "$(dirname "$0")/../.." && pwd)"
CONF="$HOME/.config/wallust/wallust.toml"
SRC="$HOME/.config/hypr/wallpaper_effects/.wallpaper_source"
img=$(cat "$SRC" 2>/dev/null || readlink -f "$HOME/.config/rofi/.current_wallpaper")
action="${1:?action}"; kind="${2:?fond|theme}"; shift 2

theme_cmd() {   # palette maison (colorschemes/<nom>.json) ou thème intégré
    if [ -f "$HOME/.config/wallust/colorschemes/$1.json" ]; then echo cs; else echo theme; fi
}

if [ "$action" = preview ]; then
    t=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/qb-wallust.XXXXXX")
    trap 'rm -rf -- "$t"' EXIT
    out="$t/palette.json"
    mkdir -p "$t/templates"
    printf '{"bg":"{{background}}","fg":"{{foreground}}","c":["{{color0}}","{{color1}}","{{color2}}","{{color3}}","{{color4}}","{{color5}}","{{color6}}","{{color7}}","{{color8}}","{{color9}}","{{color10}}","{{color11}}","{{color12}}","{{color13}}","{{color14}}","{{color15}}"]}\n' > "$t/templates/preview.json"
    if [ "$kind" = fond ]; then
        sat=""; [ "${4:-0}" != 0 ] && sat="saturation = $4"
        cat > "$t/wallust.toml" <<E
backend = "resized"
palette = "$1"
style = "$2"
use16cols = true
check_contrast = $( [ "$3" = 1 ] && echo true || echo false )
$sat
[templates]
preview.template = "preview.json"
preview.target = "$out"
E
        XDG_CACHE_HOME="$t/cache" wallust run -s -q -d "$t" "$img" >/dev/null 2>&1
    else
        cat > "$t/wallust.toml" <<E
[templates]
preview.template = "preview.json"
preview.target = "$out"
E
        cp -r "$HOME/.config/wallust/colorschemes" "$t/" 2>/dev/null || true
        XDG_CACHE_HOME="$t/cache" wallust "$(theme_cmd "$1")" "$1" -s -q -d "$t" >/dev/null 2>&1
    fi
    cat "$out"
    exit 0
fi

# ── application ──
if [ "$kind" = fond ]; then
    sat=null; [ "${4:-0}" != 0 ] && sat="$4"
    contrast=$( [ "$3" = 1 ] && echo true || echo false )
    python3 -I "$QB/scripts/config/config_set.py" "$CONF" \
        "{\"palette\": \"$1\", \"style\": \"$2\", \"check_contrast\": $contrast, \"saturation\": $sat}"
    exec "$HOME/.config/hypr/scripts/set-wallpaper.sh" "$img"
else
    wallust "$(theme_cmd "$1")" "$1" -s >/dev/null 2>&1
    pkill -USR1 -x kitty 2>/dev/null || true
    bash "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 &
fi
