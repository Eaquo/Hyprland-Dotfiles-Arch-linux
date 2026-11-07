#!/bin/sh
# coding-mode.sh on <palette> <température K | 0> | off — mode Coding (tuile des réglages rapides,
# services/CodingMode.qml) : une palette fixe et reposante pour TOUT le système (terminal, nvim, GTK, Hyprland,
# rofi, Quick-Bar, Windsurf…) + lumière chaude (hyprsunset). Palettes maison : ~/.config/wallust/colorschemes/
# coding-dark.json et coding-light.json (format pywal) ; « wallpaper-light » = le fond d'écran en clair (wallust 4) ;
# tout autre nom = un thème de `wallust theme list`. Marqueur ~/.cache/quickbar/coding-mode : tant qu'il existe,
# set-wallpaper.sh et wall-effect.sh réappliquent le thème au lieu de recolorer depuis le fond.
# « off » remet les couleurs du fond d'écran actuel, les transparences de fenêtres, et coupe hyprsunset s'il a
# été lancé par le mode.
set -eu
M="$HOME/.cache/quickbar/coding-mode"
SRC="$HOME/.config/hypr/wallpaper_effects/.wallpaper_source"
# palette : « wallpaper-light » = calculée depuis le fond d'écran en clair (wallust 4, palette salience, contraste
# vérifié) ; sinon une palette maison (colorschemes/<nom>.json) ou un thème intégré de wallust
apply() {
    if [ "$1" = wallpaper-light ]; then
        img=$(cat "$SRC" 2>/dev/null || readlink -f "$HOME/.config/rofi/.current_wallpaper")
        wallust run "$img" -s -S light -p salience -k >/dev/null 2>&1
    elif [ -f "$HOME/.config/wallust/colorschemes/$1.json" ]; then wallust cs "$1" -s >/dev/null 2>&1
    else wallust theme "$1" -s >/dev/null 2>&1; fi
}
# Windsurf : le crochet de wallust (thème Vesper + couleurs de syntaxe tirées de la palette) en sombre ; en clair,
# Vesper resterait sombre et ses couleurs illisibles → thème clair intégré « Quiet Light », sans surcharge de syntaxe
windsurf() {
    hook="$HOME/.config/wallust/hooks/windsurf-theme.py"
    [ -f "$hook" ] || return 0
    python3 "$hook" >/dev/null 2>&1 || true
    [ "$1" = light ] || return 0
    python3 - <<'PY' || true
import json, pathlib, re, sys
sys.path.insert(0, str(pathlib.Path.home() / ".config/wallust/hooks"))
f = pathlib.Path.home() / ".config/Windsurf/User/settings.json"
from importlib import util
spec = util.spec_from_file_location("wt", pathlib.Path.home() / ".config/wallust/hooks/windsurf-theme.py")
wt = util.module_from_spec(spec); spec.loader.exec_module(wt)
s = json.loads(wt.strip_jsonc(f.read_text()))
s["workbench.colorTheme"] = "Quiet Light"
for k in ("editor.tokenColorCustomizations", "editor.semanticTokenColorCustomizations"):
    s.pop(k, None)
f.write_text(json.dumps(s, indent=4, ensure_ascii=False))
PY
}
# opacité des fenêtres : notée avant de passer à 1, remise telle quelle à la sortie (un rechargement de Hyprland ne
# la rétablit pas) ; les fenêtres ouvertes pendant le mode sont opaques par une règle temporaire
OP="$M.opacite"
opaque() {
    lua=""
    for a in $(hyprctl clients -j | python3 -I -c "import json,sys; [print(c['address']) for c in json.load(sys.stdin)]"); do
        if ! grep -q "^$a " "$OP" 2>/dev/null; then
            echo "$a $(hyprctl getprop "address:$a" opacity) $(hyprctl getprop "address:$a" opacity_inactive)" >> "$OP"
        fi
        lua="$lua hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$a', prop = 'opacity', value = '1.0 override' }))"
        lua="$lua hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$a', prop = 'opacity_inactive', value = '1.0 override' }))"
    done
    hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })$lua" >/dev/null 2>&1 || true
}
restore_opacity() {
    [ -f "$OP" ] || return 0
    lua=""
    while read -r a o oi; do
        case "$o$oi" in *[!0-9.]*|"") continue ;; esac          # fenêtre fermée depuis : getprop vide
        lua="$lua hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$a', prop = 'opacity', value = '$o' }))"
        lua="$lua hl.dispatch(hl.dsp.window.set_prop({ window = 'address:$a', prop = 'opacity_inactive', value = '$oi' }))"
    done < "$OP"
    rm -f -- "$OP"
    hyprctl reload >/dev/null 2>&1 || true                      # retire la règle temporaire
    [ -n "$lua" ] && hyprctl eval "$lua" >/dev/null 2>&1 || true
}
refresh() {
    pkill -USR1 -x kitty 2>/dev/null || true
    bash "$HOME/.config/hypr/scripts/Refresh.sh" >/dev/null 2>&1 &
}

case "${1:-}" in
on)
    theme="${2:?thème manquant}"; temp="${3:-0}"
    started_sunset=0
    if [ -f "$M" ]; then started_sunset=$(sed -n 's/^sunset=//p' "$M"); fi   # changement de variante : on garde l'info
    if [ "$temp" != 0 ] && ! pgrep -x hyprsunset >/dev/null; then
        setsid -f hyprsunset -t "$temp" >/dev/null 2>&1
        started_sunset=1
    fi
    mkdir -p "${M%/*}"
    printf 'theme=%s\nsunset=%s\n' "$theme" "${started_sunset:-0}" > "$M"
    apply "$theme"
    opaque                              # pas de fond d'écran qui bouge derrière le code
    case "$theme" in *light*|*Light*|*dawn*|*Latte*|*Lotus*) windsurf light ;; *) windsurf dark ;; esac   # wallpaper-light compris
    refresh
    ;;
off)
    [ -f "$M" ] || exit 0
    started_sunset=$(sed -n 's/^sunset=//p' "$M")
    rm -f -- "$M"
    [ "$started_sunset" = 1 ] && pkill -x hyprsunset 2>/dev/null || true
    img=$(cat "$SRC" 2>/dev/null || readlink -f "$HOME/.config/rofi/.current_wallpaper")
    [ -f "$img" ] && wallust run "$img" -s >/dev/null 2>&1 || true
    windsurf dark                       # Vesper + couleurs du fond, comme avant le mode
    restore_opacity                     # tes transparences de fenêtres reviennent
    refresh
    ;;
theme)   # appelé par set-wallpaper.sh / wall-effect.sh : thème du mode Coding s'il est actif (code de sortie 0)
    [ -f "$M" ] || exit 1
    apply "$(sed -n 's/^theme=//p' "$M")"
    ;;
*) echo "usage : coding-mode.sh on <thème> <température> | off" >&2; exit 2 ;;
esac
