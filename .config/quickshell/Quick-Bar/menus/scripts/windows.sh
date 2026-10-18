# Fenêtres ouvertes : aller sur l'une d'elles (comme rofi -show window)
TEMPLATE=list
ICON="󰖯"
PLACEHOLDER="Fenêtre…"
NO_CUSTOM=1
COLUMNS=2
TABS=("󰀻|apps|apps" "󰉋|files|files" "󰆍|term|command" "󰖯|window|windows")

items() {
    hyprctl clients -j | jq -r 'sort_by(.focusHistoryID)[] | select(.workspace.id > 0 and .mapped)
        | [(.title // .class), (.class | ascii_downcase), (.workspace.id | tostring), .address] | @tsv' |
    while IFS=$'\t' read -r title cls ws addr; do
        item "$title" icon="$cls" sub="espace $ws" id="$addr"
    done
}
on_select() { hyprctl eval "hl.dispatch(hl.dsp.focus({ window = 'address:$1' }))" >/dev/null; }
