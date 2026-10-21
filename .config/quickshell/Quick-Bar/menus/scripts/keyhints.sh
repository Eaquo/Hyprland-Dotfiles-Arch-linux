# Aide-mémoire des raccourcis, construit automatiquement depuis la config Hyprland — SUPER+H
# (keyhints.py suit hyprland.lua et ses require/dofile : rien à tenir à jour à la main)
TEMPLATE=files
PROMPT="Raccourcis"
ICON="󰌌"
WIDTH=1500
PLACEHOLDER="Filtrer : SUPER, SHIFT, fenêtre, steam…"
MESSAGE="entrée / clic : lancer le raccourci  ·  ctrl+entrée : ouvrir sa config à la ligne  ·  ⚠ = en double"
NO_CUSTOM=1
KEYS=("Control-Return")

items() { python3 "$QB_DIR/menus/scripts/keyhints.py" menu; }

# entrée : lancer l'action, une fois le menu fermé et le focus rendu à la fenêtre d'avant
on_select() {
    sleep 0.35
    local msg; msg=$(python3 "$QB_DIR/menus/scripts/keyhints.py" run "$1")
    [ -n "$msg" ] && notify "Raccourci" "$msg"
}
# ctrl+entrée : l'éditeur directement sur la ligne du raccourci (id = fichier:ligne)
on_key_1() {
    local file=${1%:*} line=${1##*:}
    [ -f "$file" ] && edit "+$line" "$file"
}
