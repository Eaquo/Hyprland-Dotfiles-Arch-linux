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
# cached <clé> <secondes> commande… : sortie de la commande gardée en cache ; affichée tout de suite,
#   relancée en fond quand elle a plus de <secondes> (la 1re fois : lancée et attendue)
cached() {
    local f="${XDG_CACHE_HOME:-$HOME/.cache}/quickbar/menus/$1" ttl=$2; shift 2
    mkdir -p "${f%/*}"
    if [ -s "$f" ]; then
        cat "$f"
        [ $(( $(date +%s) - $(stat -c %Y "$f") )) -gt "$ttl" ] && { ( "$@" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f" ) >/dev/null 2>&1 & }
    else
        "$@" 2>/dev/null | tee "$f"
    fi
}

# ── actions (dans on_select) ──────────────────────────────────────────────
launch() { setsid -f "$QB_DIR/scripts/hypr/launch-main.sh" "$@" >/dev/null 2>&1; }   # app sur l'écran principal
term()   { launch kitty "$@"; }                                   # term -e htop · term --hold -e cmd
edit() {                                                         # ouvrir dans l'éditeur (edit +ligne fichier)
    local e=${EDITOR:-nvim}
    # nvim : le panneau latéral (neo-tree / nvim-tree) ouvert au démarrage est refermé, on arrive sur le fichier
    if [ "${e##*/}" = nvim ]; then term -e "$e" -c "lua vim.defer_fn(function() pcall(vim.cmd, 'Neotree close'); pcall(vim.cmd, 'NvimTreeClose') end, 150)" "$@"
    else term -e "$e" "$@"; fi
}
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
