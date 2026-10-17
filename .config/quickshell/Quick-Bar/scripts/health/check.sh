#!/bin/bash
# Bilan de santé de Quick-Bar : vérifie ce dont le shell dépend.
#   check.sh            → JSON [{id, label, ok, detail, fix}] (fix = réparation automatique possible)
#   check.sh fix <id>   → tente la réparation de ce point
#
# Ajouter une vérification = une fonction check_<id> (appelle `row`) + éventuellement
# fix_<id>, puis l'ajouter à CHECKS.

QB="$HOME/.config/quickshell/Quick-Bar"
CHECKS="openrgb rgb easyeffects hy3 hyprpm wallust discord launcher instances proxmox custom"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }
first=1
row() {   # id label ok(0|1) detail
    local fix=false
    declare -F "fix_$1" >/dev/null && fix=true
    [ -n "${CFIX[$1]}" ] && fix=true
    [ $first -eq 0 ] && printf ','
    first=0
    printf '{"id":"%s","label":"%s","ok":%s,"detail":"%s","fix":%s}' \
        "$1" "$(json_escape "$2")" "$([ "$3" = 1 ] && echo true || echo false)" "$(json_escape "$4")" "$fix"
}

# ── OpenRGB : le serveur SDK doit écouter (sinon les LED ne répondent plus) ────
check_openrgb() {
    local port; port=$(cat "$QB/scripts/rgb/script/conf/current_port.txt" 2>/dev/null || echo 6742)
    if ss -ltn 2>/dev/null | grep -q ":$port "; then row openrgb "Serveur OpenRGB" 1 "écoute sur le port $port"
    elif pgrep -x openrgb >/dev/null; then row openrgb "Serveur OpenRGB" 0 "lancé mais le port $port est fermé"
    else row openrgb "Serveur OpenRGB" 0 "pas lancé"; fi
}
fix_openrgb() {
    pkill -x openrgb; sleep 1
    setsid -f openrgb --server --startminimized >/dev/null 2>&1
    for _ in 1 2 3 4 5 6 7 8; do sleep 1; ss -ltn | grep -q ":6742 " && break; done
    bash "$QB/scripts/rgb/rgb_watch.sh" restart
}

# ── Démon RGB : watcher + son contrôleur ──────────────────────────────────────
check_rgb() {
    local w c
    w=$(pgrep -fc 'OpenRGB_Controller_Watch\.py'); c=$(pgrep -fc 'OpenRGB_Controller\.py ')
    if [ "$w" = 1 ] && [ "$c" = 1 ]; then row rgb "Démon RGB" 1 "mode $(cat "$QB/scripts/rgb/script/conf/sequence.txt" 2>/dev/null)"
    else row rgb "Démon RGB" 0 "$w watcher, $c contrôleur (attendu : 1 et 1)"; fi
}
fix_rgb() { bash "$QB/scripts/rgb/rgb_watch.sh" restart; }

# ── EasyEffects : l'égaliseur et sa sortie virtuelle ──────────────────────────
check_easyeffects() {
    if ! pgrep -x easyeffects >/dev/null; then row easyeffects "EasyEffects (égaliseur)" 0 "pas lancé"
    elif wpctl status 2>/dev/null | grep -qi "easy effects sink"; then row easyeffects "EasyEffects (égaliseur)" 1 "sortie « Easy Effects Sink » présente"
    else row easyeffects "EasyEffects (égaliseur)" 0 "lancé mais sa sortie est absente"; fi
}
fix_easyeffects() { pkill -x easyeffects; sleep 1; setsid -f easyeffects --gapplication-service >/dev/null 2>&1; sleep 3; }

# ── hy3 : plugin de disposition Hyprland ──────────────────────────────────────
check_hy3() {
    if hyprctl plugin list 2>/dev/null | grep -qi hy3; then row hy3 "Plugin hy3" 1 "chargé"
    else row hy3 "Plugin hy3" 0 "non chargé (à recompiler après une mise à jour de Hyprland)"; fi
}
fix_hy3() { bash "$HOME/.config/hypr/scripts/rebuild-hy3.sh" >/dev/null 2>&1; }

# ── Cache hyprpm : doit appartenir à l'utilisateur (jamais `sudo hyprpm`) ─────
check_hyprpm() {
    local f="/var/cache/hyprpm/$USER/state.toml"
    if [ ! -e "$f" ]; then row hyprpm "Cache hyprpm" 1 "pas de cache"
    elif [ "$(stat -c %U "$f")" = "$USER" ]; then row hyprpm "Cache hyprpm" 1 "appartient à $USER"
    else row hyprpm "Cache hyprpm" 0 "appartient à root (les plugins sautent) — Réparer demande le mot de passe"; fi
}
# Seule réparation qui demande les droits root : fenêtre de mot de passe polkit.
fix_hyprpm() { pkexec chown -R "$USER:$USER" "/var/cache/hyprpm/$USER"; }

# ── wallust : la palette lue par Quick-Bar ────────────────────────────────────
check_wallust() {
    if jq -e '.colors.color11 and .special.background' "$HOME/.cache/wal/wal.json" >/dev/null 2>&1; then
        row wallust "Palette wallust" 1 "wal.json valide"
    else row wallust "Palette wallust" 0 "~/.cache/wal/wal.json absent ou invalide"; fi
}
fix_wallust() {
    local w; w=$(readlink -f "$HOME/.config/rofi/.current_wallpaper")
    [ -f "$w" ] && wallust run "$w" -s >/dev/null 2>&1
}

# ── Discord : jeton du bot (le pont démarre avec l'onglet) ────────────────────
check_discord() {
    if [ -s "$QB/.discord_token" ]; then row discord "Jeton Discord" 1 "présent"
    else row discord "Jeton Discord" 0 "fichier .discord_token absent (onglet Discord inactif)"; fi
}

# ── game-launcher : backend de l'onglet Games ─────────────────────────────────
check_launcher() {
    if [ -f "$HOME/.config/quickshell/game-launcher/modules/service/backend.py" ]; then row launcher "Backend des jeux" 1 "game-launcher présent"
    else row launcher "Backend des jeux" 0 "game-launcher/modules/service/backend.py introuvable (onglet Games vide)"; fi
}

# ── Une seule instance de Quick-Bar ───────────────────────────────────────────
check_instances() {
    local n; n=$(quickshell list --all 2>/dev/null | grep -c "Quick-Bar/shell.qml")
    if [ "$n" -le 1 ]; then row instances "Instances Quick-Bar" 1 "une seule"
    else row instances "Instances Quick-Bar" 0 "$n instances tournent en même temps"; fi
}
# Garde l'instance qui a lancé ce script (un de nos ancêtres), tue les autres.
fix_instances() {
    local me=$$ mine=""
    while [ "$me" -gt 1 ]; do
        [ "$(cat /proc/$me/comm 2>/dev/null)" = quickshell ] && { mine=$me; break; }
        me=$(awk '{print $4}' /proc/$me/stat 2>/dev/null || echo 1)
    done
    [ -z "$mine" ] && return 1      # lancé hors de Quick-Bar : on ne sait pas laquelle garder
    quickshell list --all 2>/dev/null | awk '/Process ID/{pid=$3} /Config path/ && /Quick-Bar\/shell.qml/{print pid}' |
        while read -r p; do [ "$p" != "$mine" ] && kill -9 "$p"; done
}

# ── Proxmox : l'interface web répond (adresse dans config.toml, [health] proxmox) ─
# Vide = pas de ligne. N'importe quelle réponse HTTP = hôte joignable.
check_proxmox() {
    local host; host=$(awk -F= '/^\[/{s=($0 ~ /^\[health\]/)} s && $1 ~ /^ *proxmox *$/ {sub(/#.*/, "", $2); gsub(/[ "\t]/, "", $2); print $2}' "$QB/config.toml")
    [ -z "$host" ] && return
    # Page d'accueil, pas /api2 : sans jeton, pveproxy attend 3 s avant de répondre 401
    local code; code=$(curl -sk -m 3 -o /dev/null -w '%{http_code}' "https://$host:8006/")
    if [ "$code" != "000" ]; then row proxmox "Proxmox" 1 "$host joignable"
    else row proxmox "Proxmox" 0 "$host ne répond pas sur le port 8006"; fi
}

# ── Vérifications de l'utilisateur ([[health.custom]] dans config.toml, Réglages › Santé) ──
# Health.qml les passe en JSON dans QB_HEALTH_CUSTOM : [{name, type, target, fix?}, …]
declare -A CFIX
custom_list() { [ -n "$QB_HEALTH_CUSTOM" ] && printf '%s' "$QB_HEALTH_CUSTOM" | jq -r '.[] | [.name, .type, .target, (.fix // "")] | @tsv' 2>/dev/null; }
custom_test() {   # type cible → code 0 si ok
    case "$1" in
        process) pgrep -x "$2" >/dev/null || pgrep -f -- "$2" >/dev/null ;;
        service) systemctl --user is-active -q "$2" 2>/dev/null || systemctl is-active -q "$2" 2>/dev/null ;;
        url)     local c; c=$(curl -sk -m 4 -o /dev/null -w '%{http_code}' "$2"); [ "$c" != 000 ] && [ "$c" -lt 500 ] ;;
        host)    ping -c1 -W2 "$2" >/dev/null 2>&1 ;;
        port)    timeout 3 bash -c ">/dev/tcp/${2%:*}/${2##*:}" 2>/dev/null ;;
        file)    [ -e "${2/#\~/$HOME}" ] ;;
        mount)   mountpoint -q "${2/#\~/$HOME}" ;;
        command) timeout 10 sh -c "$2" >/dev/null 2>&1 ;;
        *)       return 1 ;;
    esac
}
custom_label() {  # type ok(0|1) cible → détail lisible
    case "$1" in
        process) [ "$2" = 1 ] && echo "$3 tourne" || echo "$3 ne tourne pas" ;;
        service) [ "$2" = 1 ] && echo "service $3 actif" || echo "service $3 inactif" ;;
        url)     [ "$2" = 1 ] && echo "$3 répond" || echo "$3 ne répond pas" ;;
        host)    [ "$2" = 1 ] && echo "$3 joignable" || echo "$3 injoignable" ;;
        port)    [ "$2" = 1 ] && echo "port $3 ouvert" || echo "port $3 fermé" ;;
        file)    [ "$2" = 1 ] && echo "$3 présent" || echo "$3 introuvable" ;;
        mount)   [ "$2" = 1 ] && echo "$3 monté" || echo "$3 n'est pas monté" ;;
        command) [ "$2" = 1 ] && echo "commande OK" || echo "la commande a échoué" ;;
    esac
}
check_custom() {
    local i=0 name type target fix
    while IFS=$'\t' read -r name type target fix; do
        i=$((i + 1))
        [ -n "$fix" ] && CFIX[custom$i]=$fix
        if custom_test "$type" "$target"; then row "custom$i" "$name" 1 "$(custom_label "$type" 1 "$target")"
        else row "custom$i" "$name" 0 "$(custom_label "$type" 0 "$target")"; fi
    done < <(custom_list)
}

# Réparation d'une vérification perso : sa commande « fix »
if [ "$1" = "fix" ] && [[ "$2" == custom* ]]; then
    n=${2#custom}
    cmd=$(printf '%s' "$QB_HEALTH_CUSTOM" | jq -r --argjson i "$((n - 1))" '.[$i].fix // empty')
    [ -n "$cmd" ] && timeout 60 sh -c "$cmd" >/dev/null 2>&1
    exit 0
fi

if [ "$1" = "fix" ] && declare -F "fix_$2" >/dev/null; then
    "fix_$2"
    exit 0
fi

printf '['
# QB_HEALTH_SKIP = vérifications désactivées ([health] skip, Réglages › Système › Santé)
for c in $CHECKS; do case " $QB_HEALTH_SKIP " in *" $c "*) continue ;; esac; "check_$c"; done
printf ']\n'
