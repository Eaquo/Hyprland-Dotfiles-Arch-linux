#!/bin/bash
# Bascule DP-1 (Huawei ultrawide, HDR10 / PQ / BT.2020, ~455 nits crête)
# entre SDR (quotidien) et HDR (films Jellyfin).
#
# Hyprland 0.56 : la config étant en Lua, `hyprctl keyword` ne fonctionne plus
# ("keyword can't work with non-legacy parsers") → on passe par `hyprctl eval`.
#
# usage: HdrToggle.sh [on|off|toggle|status]

MON='desc:Huawei Technologies Co. Inc. ZQE-CBA 0xC080F622'
NAME="DP-1"

# Réglages communs — doivent rester alignés sur configs lua/Monitors.lua
BASE='mode = [[highrr]], position = [[0x0]], scale = 1, bitdepth = 10'

# SDR : état quotidien (bureau, code, web)
SDR='cm = [[srgb]]'

# HDR : "hdredid" = primaires + luminance lues dans l'EDID du panel.
# sdrbrightness/sdrsaturation compensent le contenu SDR qui paraît terne
# quand l'écran est en mode HDR (à ajuster au goût, voir plus bas).
HDR='cm = [[hdredid]], sdrbrightness = 1.2, sdrsaturation = 1.0'

current() {
    hyprctl -j monitors | jq -r ".[] | select(.name==\"$NAME\") | .colorManagementPreset"
}

# Applique le preset puis attend que Hyprland l'ait réellement pris en compte :
# le changement est asynchrone (renégociation colorimétrie + mode-set, écran
# noir bref), donc relire l'état immédiatement renvoie l'ancienne valeur.
apply() {
    local want="$1" opts="$2"
    hyprctl eval "hl.monitor({ output = [[$MON]], $BASE, $opts })" >/dev/null
    for _ in $(seq 20); do
        [[ "$(current)" == "$want" ]] && return 0
        sleep 0.15
    done
    return 1
}

case "${1:-toggle}" in
    on|hdr)
        apply hdredid "$HDR" && echo "HDR ON  → $(current)" || echo "échec (état: $(current))" >&2
        ;;
    off|sdr)
        apply srgb "$SDR" && echo "HDR OFF → $(current)" || echo "échec (état: $(current))" >&2
        ;;
    toggle)
        if [[ "$(current)" == "srgb" ]]; then apply hdredid "$HDR"; else apply srgb "$SDR"; fi
        echo "→ $(current)"
        ;;
    status)
        current
        ;;
    *)
        echo "usage: ${0##*/} [on|off|toggle|status]" >&2
        exit 1
        ;;
esac
