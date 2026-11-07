#!/bin/bash
# gamescope-clip.sh — pont de presse-papiers entre le bureau (Wayland) et un jeu dans gamescope (son propre Xwayland).
# Sans lui, copier une deck list sur le bureau puis Ctrl+V dans MTGA ne colle rien, et « Exporter » dans le jeu
# n'arrive pas sur le bureau. Lancé par game-core.sh quand GAMESCOPE_OPTIONS=True, arrêté à la sortie du jeu.
#   gamescope-clip.sh <pid du lancement>      (trouve le gamescope et son Xwayland sous ce pid)
# ponytail: sondage 1×/s des deux presse-papiers, seulement pendant une partie en gamescope — passer à des
# événements (wl-paste --watch + XFixes) si ça devait tourner en permanence.
set -u
root_pid="${1:?pid manquant}"

# écran X du jeu : le DISPLAY de « gamescopereaper », l'enfant de gamescope qui lance le jeu (le Xwayland de gamescope
# se détache de son parent : on ne peut pas le retrouver par descendance)
find_display() {
    local p a
    for p in $(pgrep -x gamescopereaper); do
        a=$p
        while [ "$a" -gt 1 ]; do
            if [ "$a" = "$root_pid" ]; then
                tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^DISPLAY=//p' | head -1
                return
            fi
            a=$(awk '{print $4}' "/proc/$a/stat" 2>/dev/null) || break
        done
    done
}

disp=""
for _ in $(seq 60); do                     # gamescope met quelques secondes à lancer son Xwayland
    disp=$(find_display)
    [ -n "$disp" ] && break
    kill -0 "$root_pid" 2>/dev/null || exit 0
    sleep 1
done
[ -n "$disp" ] || { echo "gamescope-clip : Xwayland du jeu introuvable" >&2; exit 0; }
echo "gamescope-clip : bureau ⇄ DISPLAY=$disp"

last=""
while kill -0 "$root_pid" 2>/dev/null; do
    host=$(wl-paste -n --type text 2>/dev/null) || host=""
    game=$(DISPLAY="$disp" timeout 1 xclip -selection clipboard -o 2>/dev/null) || game=""
    if [ -n "$host" ] && [ "$host" != "$last" ] && [ "$host" != "$game" ]; then
        printf '%s' "$host" | DISPLAY="$disp" xclip -selection clipboard -i      # bureau → jeu
        last=$host
    elif [ -n "$game" ] && [ "$game" != "$last" ] && [ "$game" != "$host" ]; then
        printf '%s' "$game" | wl-copy                                            # jeu → bureau
        last=$game
    fi
    sleep 1
done
