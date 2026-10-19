# Bluetooth : allumer, connecter, appairer, oublier — CTRL+B (ou clic molette sur la tuile Bluetooth)
TEMPLATE=list
PROMPT="Bluetooth"
ICON="󰂯"
WIDTH=860
PLACEHOLDER="Chercher un appareil…"
MESSAGE="entrée : connecter / déconnecter  ·  ctrl+suppr : oublier l'appareil"
KEYS=("Control-Delete")
KEEP_OPEN=1
NO_CUSTOM=1

glyph_of() {
    case $1 in
        audio-headphones|audio-headset) echo "󰋋" ;;
        audio-card|audio-speakers)      echo "󰓃" ;;
        input-gaming)                   echo "󰊴" ;;
        input-keyboard)                 echo "󰌌" ;;
        input-mouse)                    echo "󰍽" ;;
        phone)                          echo "󰏲" ;;
        computer)                       echo "󰟀" ;;
        *)                              echo "󰂯" ;;
    esac
}

items() {
    if [ "$(bluetoothctl show | awk '/Powered:/{print $2}')" != yes ]; then
        item "Bluetooth éteint" id=power glyph="󰂲" sub="entrée : allumer"
        return
    fi
    item "Bluetooth activé" id=power glyph="󰂯" sub="entrée : éteindre"
    section "Appareils"
    local mac name info st bat
    while read -r _ mac name; do
        info=$(bluetoothctl info "$mac")
        bat=$(grep -oP 'Battery Percentage: 0x[0-9a-f]+ \(\K[0-9]+' <<<"$info")
        if grep -q "Connected: yes" <<<"$info"; then st="connecté${bat:+ · $bat %}"
        elif grep -q "Paired: yes" <<<"$info"; then st="appairé"
        else st="nouveau — entrée pour appairer"; fi
        item "$name" id="$mac" glyph="$(glyph_of "$(awk '/Icon:/{print $2}' <<<"$info")")" sub="$st"
    done < <(bluetoothctl devices)
    section "Actions"
    item "Rechercher de nouveaux appareils" id=scan glyph="󰑓" sub="10 secondes"
}

on_select() {
    case $1 in
        power)
            if [ "$(bluetoothctl show | awk '/Powered:/{print $2}')" = yes ]; then bluetoothctl power off >/dev/null
            else bluetoothctl power on >/dev/null; fi ;;
        scan)
            notify "Bluetooth" "Recherche d'appareils (10 s)…"
            bluetoothctl --timeout 10 scan on >/dev/null 2>&1 ;;
        *)
            local info name
            info=$(bluetoothctl info "$1"); name=$(awk -F': ' '/Name:/{print $2; exit}' <<<"$info")
            if grep -q "Connected: yes" <<<"$info"; then
                bluetoothctl disconnect "$1" >/dev/null && notify "Bluetooth" "$name déconnecté"
            else
                grep -q "Paired: yes" <<<"$info" || { bluetoothctl pair "$1" >/dev/null; bluetoothctl trust "$1" >/dev/null; }
                if bluetoothctl connect "$1" >/dev/null 2>&1; then notify "Bluetooth" "$name connecté"
                else notify -u critical "Bluetooth" "Connexion à $name impossible"; fi
            fi ;;
    esac
}
on_key_1() { [[ $1 =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]] && confirm "Oublier cet appareil ?" && bluetoothctl remove "$1" >/dev/null; }
