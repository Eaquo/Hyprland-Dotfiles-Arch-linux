# Éditer une config : d'abord Lua, conf de base ou Quick-Bar, puis le fichier (aperçu à droite) — SUPER+MAJ+E
TEMPLATE=grid
PROMPT="Config"
ICON=""
COLUMNS=3
WIDTH=960
MESSAGE="Quel type de config ?"
NO_CUSTOM=1

HYPR="$HOME/.config/hypr"

items() {
    item "Config Lua"              id=lua  glyph=""
    item "Config de base (.conf)"  id=conf glyph=""
    item "Quick-Bar"               id=qb   glyph="󰍜"
}

# 2ᵉ étape : les fichiers du type choisi, avec aperçu
files_of() {
    local f
    case $1 in
        lua)  for f in "$HYPR"/*.lua "$HYPR/configs lua"/*.lua; do item "$(basename "$f")" id="$f" glyph="󰢱" sub="${f#$HYPR/}"; done ;;
        conf) for f in "$HYPR"/*.conf "$HYPR/configs"/*.conf; do [ -f "$f" ] && item "$(basename "$f")" id="$f" glyph="󰈙" sub="${f#$HYPR/}"; done ;;
        qb)   item "config.toml" id="$QB_DIR/config.toml" glyph="󰒓" sub="réglages Quick-Bar"
              item "quickbar.lua" id="$QB_DIR/hypr/quickbar.lua" glyph="󰌌" sub="raccourcis générés"
              for f in "$QB_DIR/menus/scripts"/*.sh; do item "menus/$(basename "$f")" id="$f" glyph="󰍜" sub="menu Quick-Bar"; done ;;
    esac
}
# Retour (ou Échap) dans la liste des fichiers → revenir aux trois cartes
on_select() {
    local titre file
    KEEP_OPEN=0
    case $1 in lua) titre="Config Lua" ;; conf) titre="Config de base" ;; *) titre="Quick-Bar" ;; esac
    file=$( { item "Retour" id=back glyph="󰁍" sub="revenir au choix"; files_of "$1"; } |
            "$QBMENU" --template files -p "$titre" --icon "󰒓" --placeholder "Chercher un fichier…" -no-custom -selected-row 1)
    if [ -z "$file" ] || [ "$file" = back ]; then KEEP_OPEN=1; return; fi
    edit "$file"
}
