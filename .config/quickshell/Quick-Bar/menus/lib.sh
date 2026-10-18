# lib.sh — fonctions disponibles dans les scripts de menus (menus/scripts/*.sh). Voir README.md.

QB_DIR=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
QBMENU="$QB_DIR/menus/qbmenu"

# ── construire la liste (dans items) ──────────────────────────────────────
# item "Texte" [clé=valeur …]   clés : icon= (nom d'icône ou chemin d'image) glyph= sub= id= path= colors=
#   Tabulations dans le texte = colonnes (template list / info).
item() {
    local text=$1; shift
    local meta="" kv
    for kv in "$@"; do meta+="${kv%%=*}"$'\x1f'"${kv#*=}"$'\x1f'; done
    if [ -n "$meta" ]; then printf '%s\0%s\n' "$text" "${meta%$'\x1f'}"; else printf '%s\n' "$text"; fi
}
section() { item "$1" nonselectable=true; }      # titre de section (non sélectionnable)

# ── actions (dans on_select) ──────────────────────────────────────────────
launch() { setsid -f "$QB_DIR/scripts/hypr/launch-main.sh" "$@" >/dev/null 2>&1; }   # app sur l'écran principal
term()   { launch kitty "$@"; }                                   # term -e htop · term --hold -e cmd
edit()   { term -e "${EDITOR:-nvim}" "$@"; }                      # ouvrir un fichier dans l'éditeur
copy()   { printf '%s' "$*" | wl-copy; }                          # copier dans le presse-papiers
open()   { setsid -f xdg-open "$@" >/dev/null 2>&1; }             # URL ou fichier
notify() { notify-send -a Quick-Bar "$@"; }
qb()     { qs -p "$QB_DIR/shell.qml" ipc call "$@"; }             # piloter Quick-Bar : qb wallpicker toggle

# ── petites questions (sous-menus) ────────────────────────────────────────
# ask "Titre" choix1 choix2 …     → imprime le choix (code 1 si annulé)
ask()     { local p=$1; shift; printf '%s\n' "$@" | "$QBMENU" --template list -p "$p" -no-custom; }
# confirm "Supprimer ce fichier ?" → code 0 si Oui
confirm() { [ "$("$QBMENU" --template confirm --title "$1" </dev/null)" = "Oui" ]; }
# input "Nom du jeu" ["texte d'aide"] → imprime la saisie
input()   { "$QBMENU" --template input -p "$1" --placeholder "${2:-}" </dev/null; }
