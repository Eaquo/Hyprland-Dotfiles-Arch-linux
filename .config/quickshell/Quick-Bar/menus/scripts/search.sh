# Recherche web dans le navigateur par défaut — SUPER+MAJ+Z
TEMPLATE=input
PROMPT="Recherche"
ICON="󰖟"
PLACEHOLDER="Rechercher sur le web…"

on_select() {
    [ -n "$1" ] && open "https://www.google.com/search?q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1")"
}
