#!/bin/bash
# Bilan de santé de Quick-Bar : vérifie ce dont le shell dépend.
#   check.sh            → JSON [{id, label, ok, detail, fix}] (fix = réparation automatique possible)
#   check.sh fix <id>   → tente la réparation de ce point
#
# Ajouter une vérification = une fonction check_<id> (appelle `row`) + éventuellement
# fix_<id>, puis l'ajouter à CHECKS.

QB="$HOME/.config/quickshell/Quick-Bar"
CHECKS="openrgb rgb easyeffects hy3 hyprpm wallust discord launcher instances"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }
first=1
row() {   # id label ok(0|1) detail
    local fix=false
    declare -F "fix_$1" >/dev/null && fix=true
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

if [ "$1" = "fix" ] && declare -F "fix_$2" >/dev/null; then
    "fix_$2"
    exit 0
fi

printf '['
for c in $CHECKS; do "check_$c"; done
printf ']\n'
