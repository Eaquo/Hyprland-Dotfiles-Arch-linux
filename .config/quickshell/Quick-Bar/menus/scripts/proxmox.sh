# Mises à jour Proxmox : l'hôte et chaque LXC (apt), le changelog Debian à droite ; entrée = un paquet, un conteneur ou tout
TEMPLATE=files
PROMPT="Proxmox"
ICON="󰒋"
WIDTH=1300
PLACEHOLDER="Chercher un paquet, un conteneur…"
MESSAGE="à droite : le changelog (maj+↑↓ pour défiler)  ·  entrée : mettre à jour"
NO_CUSTOM=1
KEEP_OPEN=1

# l'adresse du serveur : la même que l'onglet Santé (config.toml, [health] proxmox) ; connexion root par clé SSH
PVE=$(awk -F= '/^\[/{s=($0 ~ /^\[health\]/)} s && $1 ~ /^ *proxmox *$/ {sub(/#.*/, "", $2); gsub(/[ "\t]/, "", $2); print $2}' "$QB_DIR/config.toml")
CL=${XDG_RUNTIME_DIR:-/tmp}/qb-proxmox
LIST=$CL/list.txt      # « <cible> nom ancienne -> nouvelle » ; cible = host ou n° du LXC
TARGETS=$CL/targets.txt  # « <cible> nom état »
mkdir -p "$CL"
# une seule connexion SSH partagée par toutes les commandes (ControlMaster)
SSH=(ssh -n -o BatchMode=yes -o ConnectTimeout=5 -o ControlMaster=auto -o "ControlPath=$CL/ssh-%C" -o ControlPersist=120 "root@$PVE")
APTLIST='apt-get update -qq >/dev/null 2>&1; apt list --upgradable 2>/dev/null | sed 1d'

if [ ! -e "$LIST" ] || [ $(( $(date +%s) - $(stat -c %Y "$LIST") )) -gt 2100 ]; then
    TEMPLATE=scan; WIDTH=900; MESSAGE=""
fi

# on <cible> commande : sur l'hôte ou dans le conteneur
on() { if [ "$1" = host ]; then "${SSH[@]}" "$2"; else "${SSH[@]}" "pct exec $1 -- sh -c '$2'"; fi; }

# changelog <cible> <nom> <de> <à> : les entrées Debian depuis la version installée → $CL/<cible>-<nom>.txt
changelog() {
    local f="$CL/$1-$2.txt" log src slug
    log=$(on "$1" "apt-get changelog -qq $2 2>&1")
    # mise à jour de sécurité : pas sur metadata.ftp-master (404) → l'annonce « Accepted … » de tracker.debian.org
    if [[ $log =~ Changelog\ unavailable\ for\ ([^=]+)=([^ ]+) ]]; then
        src=${BASH_REMATCH[1]}; slug=$(tr -cd 'a-z0-9-' <<<"${BASH_REMATCH[2],,}")
        log=$(curl -fsm 8 "https://tracker.debian.org/pkg/$src/news/" | grep -oE "/news/[0-9]+/accepted-$(tr -cd 'a-z0-9-' <<<"$src")-$slug-[^\"]*" | head -1)
        log=$([ -n "$log" ] && curl -fsm 8 "https://tracker.debian.org$log" | sed -n '/^Changes:/,/^Checksums/{/^Changes:/d;/^Checksums/d;s/^ //;s/^\.$//;p}' \
                  | python3 -c 'import html,sys; print(html.unescape(sys.stdin.read()), end="")' \
              || echo "(changelog introuvable : https://tracker.debian.org/pkg/$src)")
    fi
    { printf '%s   %s → %s\n\n' "$2" "$3" "$4"
      awk -v o="($3)" 'NR > 1 && index($0, o) { exit } { print }' <<<"$log" | head -120
    } > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
}

scan() {
    local n i=0 j=0 t name st all="" k
    "${SSH[@]}" true 2>/dev/null || { echo "STEP 1 1 $PVE injoignable (ssh root@$PVE)"; : > "$LIST"; echo DONE; return; }
    { echo "host $(on host hostname) running"; on host "pct list" | awk 'NR > 1 { print $1, $NF, $2 }'; } > "$TARGETS"
    n=$(( $(grep -c . "$TARGETS") + 1 ))
    while read -r t name st; do
        i=$((i + 1))
        [ "$st" = running ] || continue
        echo "STEP $i $n $([ "$t" = host ] && echo "Hôte $name" || echo "LXC $t · $name") (apt update)"
        k=$(on "$t" "$APTLIST" | awk -v t="$t" '{ split($1, a, "/"); o = $NF; sub(/]$/, "", o); print t, a[1], o, "->", $2 }')
        [ -n "$k" ] && { awk '{ print "ITEM " $2 }' <<<"$k"; all+="$k"$'\n'; }
    done < "$TARGETS"
    echo "STEP $n $n Changelogs"
    # un fil par cible (en parallèle), les paquets d'une cible l'un après l'autre
    local tot; tot=$(grep -c . <<<"$all")
    if [ "$tot" -gt 0 ]; then
        for t in $(awk '{ print $1 }' <<<"$all" | sort -u); do
            ( grep "^$t " <<<"$all" | while read -r _ name from _ to; do changelog "$t" "$name" "$from" "$to"; echo x; done ) &
        done | while read -r _; do j=$((j + 1)); echo "SUB $j $tot"; done
    fi
    printf '%s' "$all" > "$LIST.tmp" && mv "$LIST.tmp" "$LIST"
    echo DONE
    sleep 0.9
    [ -n "${QB_QUIET:-}" ] || setsid -f "$QB_DIR/menus/run.sh" proxmox >/dev/null 2>&1   # QB_QUIET : scan du module de la barre
}

items() {
    if [ "$TEMPLATE" = scan ]; then item "Recherche des mises à jour Proxmox" id=scan sub="hôte · conteneurs LXC · changelogs" cmd="'$QB_DIR/menus/run.sh' proxmox --call scan"; return; fi
    local n t name st k c ok=()
    n=$(grep -c . "$LIST")
    printf 'Rechercher à nouveau (hôte, conteneurs, changelogs).\n' > "$CL/_rescan.txt"
    printf 'Interface web : https://%s:8006\n' "$PVE" > "$CL/_web.txt"
    if [ "$n" -eq 0 ]; then
        item "Proxmox est à jour" id=none glyph="󰄬" sub="hôte et conteneurs"
    else
        { printf 'Tout mettre à jour (%s paquets)\n\nDans un terminal, conteneur par conteneur puis l'"'"'hôte :\n\n' "$n"
          awk '{ print $1 }' "$LIST" | uniq -c | while read -r c t; do printf '  %-6s %s paquet(s)\n' "$t" "$c"; done; } > "$CL/_all.txt"
        item "Tout mettre à jour" id=all glyph="󰚰" path="$CL/_all.txt" sub="$n paquet(s) · hôte et LXC"
    fi
    item "Rechercher à nouveau" id=rescan glyph="󰑐" path="$CL/_rescan.txt" sub="liste du $(date -r "$LIST" '+%H:%M')"
    item "Interface web" id=web glyph="󰖟" path="$CL/_web.txt" sub="$PVE:8006"
    while read -r t name st; do
        k=$(grep "^$t " "$LIST")
        if [ -z "$k" ]; then ok+=("$t·$name$([ "$st" = running ] || echo " (arrêté)")"); continue; fi
        section "$([ "$t" = host ] && echo "Hôte · $name" || echo "LXC $t · $name")"
        { printf '%s — %s paquet(s)\n\n' "$name" "$(grep -c . <<<"$k")"; awk '{ printf "  %-32s %s → %s\n", $2, $3, $5 }' <<<"$k"; } > "$CL/$t.txt"
        item "Mettre à jour $name" id="target:$t:$name" glyph="󰚰" path="$CL/$t.txt" sub="$(grep -c . <<<"$k") paquet(s)"
        local miss=""
        while read -r _ pkg from _ to; do
            [ -s "$CL/$t-$pkg.txt" ] || { printf '%s   %s → %s\n\nchargement du changelog…\n' "$pkg" "$from" "$to" > "$CL/$t-$pkg.txt"
                                          miss+="$pkg $from $to"$'\n'; }
            item "$pkg" id="pkg:$t:$pkg" glyph="$([ "$t" = host ] && echo 󰒋 || echo 󰏗)" path="$CL/$t-$pkg.txt" sub="$from → $to"
        done <<<"$k"
        # un seul fil par cible : sshd refuse plus de 10 sessions sur la connexion partagée (MaxSessions)
        [ -n "$miss" ] && ( while read -r pkg from to; do [ -n "$pkg" ] && changelog "$t" "$pkg" "$from" "$to"; done <<<"$miss" >/dev/null 2>&1 & )
    done < "$TARGETS"
    [ ${#ok[@]} -gt 0 ] && { section "À jour"; for k in "${ok[@]}"; do item "${k#*·}" id=none glyph="󰄬" sub="${k%%·*}"; done; }
}

# upgrade <commande distante> : dans un terminal (ssh -t), puis la liste est à refaire
# après : nouveau scan en fond (survit à la fermeture du terminal) → le module de la barre relit la liste
upgrade() { KEEP_OPEN=0; rm -f "$LIST"; term -e bash -c 'ssh -t "root@$1" "$2"; QB_QUIET=1 setsid -f "$3/menus/run.sh" proxmox --call scan >/dev/null 2>&1; echo; read -rsp "Terminé — Entrée pour fermer…"' _ "$PVE" "$1" "$QB_DIR"; }
UP='apt-get update && DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y'
lxc_up() { echo "echo; echo \"━━ 󰒋 LXC $1 ━━\"; pct exec $1 -- sh -c '$UP'"; }

on_select() {
    local t name
    case $1 in
        all)
            ask "Tout mettre à jour : les conteneurs puis l'hôte ?" "Tout mettre à jour" "Retour" | grep -q Tout || return
            local cmd=""
            for t in $(awk '$1 != "host" { print $1 }' "$LIST" | sort -u); do cmd+="$(lxc_up "$t"); "; done
            grep -q '^host ' "$LIST" && cmd+="echo; echo '━━ Hôte ━━'; apt-get update && apt-get dist-upgrade"   # l'hôte : on confirme dans le terminal
            upgrade "$cmd" ;;
        rescan) KEEP_OPEN=0; rm -f "$LIST"; setsid -f "$QB_DIR/menus/run.sh" proxmox >/dev/null 2>&1 ;;
        web)    KEEP_OPEN=0; open "https://$PVE:8006" ;;
        target:*)
            t=${1#target:}; name=${t#*:}; t=${t%%:*}
            ask "$name" "Mettre à jour $name" "Retour" | grep -q Mettre || return
            if [ "$t" = host ]; then upgrade "apt-get update && apt-get dist-upgrade"; else upgrade "$(lxc_up "$t")"; fi ;;
        pkg:*)
            t=${1#pkg:}; name=${t#*:}; t=${t%%:*}
            ask "$name" "Mettre à jour $name seul" "Retour" | grep -q Mettre || return
            if [ "$t" = host ]; then upgrade "apt-get install --only-upgrade $name"
            else upgrade "pct exec $t -- apt-get install --only-upgrade -y $name"; fi ;;
        *) KEEP_OPEN=0 ;;
    esac
}
