# Tous les menus Quick-Bar (ce dossier) : en choisir un pour le lancer
TEMPLATE=list
PROMPT="Menus"
ICON="󰍜"
NO_CUSTOM=1

items() {
    local f n d
    for f in "$QB_DIR/menus/scripts/"*.sh; do
        n=$(basename "$f" .sh); [ "$n" = menus ] && continue
        d=$(grep -m1 '^# ' "$f" | sed 's/^# //')
        item "$n" id="$n" sub="$d" glyph="$(grep -m1 '^ICON=' "$f" | cut -d'"' -f2)"
    done
}
on_select() { setsid -f "$QB_DIR/menus/run.sh" "$1" >/dev/null 2>&1; }
