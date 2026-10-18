# Presse-papiers (cliphist) : recopier, supprimer une entrée, tout vider — SUPER+ALT+V
TEMPLATE=list
PROMPT="Presse-papiers"
ICON="󰅌"
WIDTH=960
MESSAGE="ctrl+suppr : supprimer l'entrée  ·  alt+suppr : tout vider"
KEYS=("Control-Delete" "Alt-Delete")
KEEP_OPEN=1
NO_CUSTOM=1

items()    { cliphist list; }
on_select() { cliphist decode <<<"$1" | wl-copy; KEEP_OPEN=0; }
on_key_1() { cliphist delete <<<"$1"; }
on_key_2() { confirm "Vider tout le presse-papiers ?" && cliphist wipe; }
