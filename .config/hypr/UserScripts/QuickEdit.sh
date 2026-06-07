#!/bin/bash

edit=${EDITOR:-nvim}
tty=kitty

# Paths
UserConfigs="$HOME/.config/hypr/UserConfigs"
UserConfigsLua="$HOME/.config/hypr/configs lua"

rofi_theme="~/.config/rofi/config-edit.rasi"

# Tuer rofi si déjà ouvert
if pidof rofi > /dev/null; then
    pkill rofi
    exit 0
fi

# ── Étape 1 : Lua ou Conf ? ───────────────────────────────────────────────────
type_choice=$(printf "📜  Lua\n📄  Conf (legacy)" | \
    rofi -i -dmenu -config "$rofi_theme" \
    -mesg " 🖊️ Quel type de config ?" | \
    awk '{print $2}')

case "$type_choice" in
    Lua)
        search_dir="$UserConfigsLua"
        ext="lua"
        ;;
    Conf)
        search_dir="$UserConfigs"
        ext="conf"
        ;;
    *)
        exit 0
        ;;
esac

# ── Étape 2 : listing dynamique du dossier ────────────────────────────────────
# Liste tous les .lua ou .conf, affiche juste le nom sans extension
file_choice=$(find "$search_dir" -maxdepth 1 -name "*.${ext}" | \
    sort | \
    while read -r f; do
        basename "$f" ".${ext}"
    done | \
    rofi -i -dmenu -config "$rofi_theme" \
    -mesg " Choisir le fichier à éditer ")

# Rien choisi → exit
[ -z "$file_choice" ] && exit 0

# ── Ouvrir le fichier ─────────────────────────────────────────────────────────
file="$search_dir/${file_choice}.${ext}"

if [ -f "$file" ]; then
    $tty -e $edit "$file"
else
    notify-send "QuickEdit" "Fichier introuvable : $file" --icon=dialog-error
fi