#!/usr/bin/env bash
# run.sh <script> [args…] — lance le menu menus/scripts/<script>.sh (appelé par `qbmenu run`).
HERE=$(dirname "$(readlink -f "$0")")
name=${1:?usage : qbmenu run <script> [args]}; shift
SCRIPT="$HERE/scripts/$name.sh"
[ -f "$SCRIPT" ] || { notify-send -a Quick-Bar "Menu inconnu" "$SCRIPT"; exit 2; }

source "$HERE/lib.sh"
# valeurs par défaut (le script les remplace)
TEMPLATE=list POSITION=center WIDTH="" HEIGHT="" COLUMNS="" ROW_HEIGHT=""
PROMPT="" ICON="" PLACEHOLDER="" MESSAGE="" TITLE="" SELECTED=""
KEEP_OPEN=0 NO_CUSTOM=0 PASSWORD=0
KEYS=()
TABS=()   # TABS=("󰀻|apps|apps" "󰉋|files|files") : onglets « glyphe|libellé|script »
source "$SCRIPT"

# appelé par le menu à chaque frappe quand le script définit live()
if [ "${1:-}" = "--live-query" ]; then live "${2:-}"; exit; fi

args=(--template "$TEMPLATE" --position "$POSITION" --script "$name")
[ -n "$WIDTH" ]       && args+=(--width "$WIDTH")
[ -n "$HEIGHT" ]      && args+=(--height "$HEIGHT")
[ -n "$COLUMNS" ]     && args+=(--columns "$COLUMNS")
[ -n "$ROW_HEIGHT" ]  && args+=(--row-height "$ROW_HEIGHT")
[ -n "$PROMPT" ]      && args+=(-p "$PROMPT")
[ -n "$ICON" ]        && args+=(--icon "$ICON")
[ -n "$PLACEHOLDER" ] && args+=(--placeholder "$PLACEHOLDER")
[ -n "$MESSAGE" ]     && args+=(-mesg "$MESSAGE")
[ -n "$TITLE" ]       && args+=(--title "$TITLE")
[ -n "$SELECTED" ]    && args+=(-selected-row "$SELECTED")
[ "$NO_CUSTOM" = 1 ]  && args+=(-no-custom)
[ "$PASSWORD" = 1 ]   && args+=(-password)
declare -F live >/dev/null && args+=(--live "'$HERE/run.sh' '$name' --live-query \"\$1\"")
for t in "${TABS[@]}"; do args+=(--tab "$t"); done
[ ${#TABS[@]} -gt 0 ] && args+=(--tab-current "$name")
for i in "${!KEYS[@]}"; do args+=(-kb-custom-$((i + 1)) "${KEYS[$i]}"); done

while :; do
    if declare -F items >/dev/null; then out=$(items "$@" | "$QBMENU" "${args[@]}")
    else out=$("$QBMENU" "${args[@]}" </dev/null); fi
    code=$?
    case $code in
        0) declare -F on_select >/dev/null && on_select "$out" "$@" ;;
        1) declare -F on_cancel >/dev/null && on_cancel; break ;;
        *) fn=on_key_$((code - 9)); declare -F "$fn" >/dev/null && "$fn" "$out" "$@" ;;
    esac
    [ "$KEEP_OPEN" = 1 ] || break
done
