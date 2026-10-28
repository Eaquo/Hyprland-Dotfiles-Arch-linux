# Mises à jour du système : la liste des paquets (dépôts et AUR) avec leur changelog à droite ; entrée = mettre à jour ce paquet ou tout
TEMPLATE=files
PROMPT="Mises à jour"
ICON="󰚰"
WIDTH=1300
PLACEHOLDER="Chercher un paquet…"
MESSAGE="à droite : le changelog (maj+↑↓ pour défiler)  ·  entrée : mettre à jour"
NO_CUSTOM=1
KEEP_OPEN=1

CL=${XDG_RUNTIME_DIR:-/tmp}/qb-updates
LIST=$CL/list.txt      # « R|A nom ancienne -> nouvelle », écrit par services/Updates.qml ou par scan()
# liste de moins de 35 min : ouverture directe ; sinon d'abord la fenêtre de scan (template scan)
if [ ! -e "$LIST" ] || [ $(( $(date +%s) - $(stat -c %Y "$LIST") )) -gt 2100 ]; then
    TEMPLATE=scan; WIDTH=900; MESSAGE=""
fi

# changelog <dépôt|aur> <nom> <de> <à> : écrit $CL/<nom>.txt (lancé en fond, un par paquet)
changelog() {
    local kind=$1 name=$2 from=$3 to=$4 f="$CL/$2.txt" info url
    if [ "$kind" = aur ]; then info=$(paru -Si --aur "$name" 2>/dev/null); else info=$(pacman -Si "$name" 2>/dev/null); fi
    url=$(sed -n 's/^URL *: //p' <<<"$info" | head -1)
    {
        printf '%s   %s → %s\n' "$name" "$from" "$to"
        sed -n 's/^Description *: /\n/p' <<<"$info" | head -2
        [ -n "$url" ] && printf '%s\n' "$url"
        # nouveautés du projet : GitHub (commits pour un paquet -git, sinon dernières versions publiées)
        if [[ $url =~ github\.com/([^/]+)/([^/#?]+) ]]; then
            local gh="${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
            if [[ $name == *-git ]]; then
                printf '\n── Derniers commits du projet ──────────────\n'
                curl -fsm 6 "https://api.github.com/repos/$gh/commits?per_page=15" | python3 -c '
import json,sys
for c in json.load(sys.stdin): print(c["commit"]["author"]["date"][:10], " ", c["commit"]["message"].splitlines()[0][:90])' 2>/dev/null
            else
                printf '\n── Notes de version ────────────────────────\n'
                curl -fsm 6 "https://api.github.com/repos/$gh/releases?per_page=3" | python3 -c '
import json,sys
for r in json.load(sys.stdin):
    print("▸", r.get("tag_name",""), " ", (r.get("published_at") or "")[:10])
    for l in (r.get("body") or "").replace("\r","").splitlines()[:30]: print("  ", l)
    print()' 2>/dev/null
            fi
        fi
        # historique de l'empaquetage (Arch / AUR)
        printf '\n── Historique du paquet ────────────────────\n'
        if [ "$kind" = aur ]; then
            curl -fsm 6 "https://aur.archlinux.org/cgit/aur.git/atom/?h=$name" | python3 -c '
import sys,re
x=sys.stdin.read()
for t,d in re.findall(r"<entry>\s*<title>(.*?)</title>\s*<updated>(.{10})", x, re.S)[:10]: print(d, " ", t)' 2>/dev/null
        else
            curl -fsm 6 "https://gitlab.archlinux.org/api/v4/projects/archlinux%2Fpackaging%2Fpackages%2F$name/repository/commits?per_page=10" | python3 -c '
import json,sys
for c in json.load(sys.stdin): print(c["created_at"][:10], " ", c["title"][:90])' 2>/dev/null \
            || printf '(pas d'"'"'historique Arch pour ce paquet : dépôt CachyOS ou nom de base différent)\n'
        fi
    } > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
}

# scan : les étapes pour le template scan, puis la liste dans la même fenêtre
scan() {
    mkdir -p "$CL"
    local repo aur all i=0 n
    echo "STEP 1 3 Dépôts officiels (checkupdates)"
    repo=$(checkupdates 2>/dev/null | sed 's/^/R /')
    [ -n "$repo" ] && cut -d' ' -f2 <<<"$repo" | sed 's/^/ITEM /'
    echo "STEP 2 3 AUR (paru)"
    aur=$(paru -Qua 2>/dev/null | sed 's/^/A /')
    [ -n "$aur" ] && cut -d' ' -f2 <<<"$aur" | sed 's/^/ITEM /'
    all=$(printf '%s\n%s\n' "$repo" "$aur" | grep .)
    n=$(grep -c . <<<"$all")
    echo "STEP 3 3 Changelogs"
    if [ "$n" -gt 0 ]; then
        while read -r k name from _ to; do
            ( changelog "$([ "$k" = A ] && echo aur || echo repo)" "$name" "$from" "$to"; echo x ) &
        done <<<"$all" | while read -r _; do i=$((i + 1)); echo "SUB $i $n"; done
    fi
    printf '%s\n' "$all" > "$LIST.tmp" && mv "$LIST.tmp" "$LIST"
    echo DONE
    sleep 0.9
    setsid -f "$QB_DIR/menus/run.sh" updates >/dev/null 2>&1      # la liste remplace le scan, sans refermer
}

items() {
    if [ "$TEMPLATE" = scan ]; then item "Recherche des mises à jour" id=scan sub="dépôts · AUR · changelogs" cmd="'$QB_DIR/menus/run.sh' updates --call scan"; return; fi
    local repo aur
    repo=$(sed -n 's/^R //p' "$LIST"); aur=$(sed -n 's/^A //p' "$LIST")
    local n=$(( $(grep -c . <<<"$repo") + $(grep -c . <<<"$aur") ))
    if [ "$n" -eq 0 ]; then item "Le système est à jour" id=none glyph="󰄬" sub="rien à installer"
        item "Rechercher à nouveau" id=rescan glyph="󰑐" sub="relancer la recherche"; return; fi
    mkdir -p "$CL"
    printf 'Tout mettre à jour (%s paquets)\n\nsudo pacman -Syu puis paru -Sua, dans un terminal.\n' "$n" > "$CL/_all.txt"
    item "Tout mettre à jour" id=all glyph="󰚰" path="$CL/_all.txt" sub="$n paquet(s) · dans un terminal"
    printf 'Relancer la recherche (dépôts, AUR, changelogs).\n' > "$CL/_rescan.txt"
    item "Rechercher à nouveau" id=rescan glyph="󰑐" path="$CL/_rescan.txt" sub="liste du $(date -r "$LIST" '+%H:%M')"
    printf 'Mises à jour du serveur Proxmox : l'"'"'hôte et ses conteneurs LXC (menu proxmox).\n' > "$CL/_proxmox.txt"
    item "Proxmox" id=proxmox glyph="󰒋" path="$CL/_proxmox.txt" sub="hôte et conteneurs LXC"
    # les changelogs arrivent en fond : l'aperçu se remplit au fil de la navigation
    if [ -n "$repo" ]; then
        section "Dépôts officiels"
        while read -r name from _ to; do
            [ -s "$CL/$name.txt" ] || { printf '%s   %s → %s\n\nchargement du changelog…\n' "$name" "$from" "$to" > "$CL/$name.txt"
                                        ( changelog repo "$name" "$from" "$to" >/dev/null 2>&1 & ); }
            item "$name" id="repo:$name" glyph="󰏗" path="$CL/$name.txt" sub="$from → $to"
        done <<<"$repo"
    fi
    if [ -n "$aur" ]; then
        section "AUR"
        while read -r name from _ to; do
            [ -s "$CL/$name.txt" ] || { printf '%s   %s → %s\n\nchargement du changelog…\n' "$name" "$from" "$to" > "$CL/$name.txt"
                                        ( changelog aur "$name" "$from" "$to" >/dev/null 2>&1 & ); }
            item "$name" id="aur:$name" glyph="󰣇" path="$CL/$name.txt" sub="$from → $to"
        done <<<"$aur"
    fi
}

# met à jour dans un terminal, puis rafraîchit le module de la barre
upgrade_in_term() { KEEP_OPEN=0; term -e bash -c "$1; qs -p '$QB_DIR/shell.qml' ipc call updates refresh; echo; read -rsp 'Terminé — Entrée pour fermer…'"; }

on_select() {
    local name=${1#*:}
    case $1 in
        all)    KEEP_OPEN=0; qb updates upgrade ;;
        rescan) KEEP_OPEN=0; rm -f "$LIST"; setsid -f "$QB_DIR/menus/run.sh" updates >/dev/null 2>&1 ;;
        proxmox) KEEP_OPEN=0; setsid -f "$QB_DIR/menus/run.sh" proxmox >/dev/null 2>&1 ;;
        aur:*)
            case $(ask "$name" "Mettre à jour $name" "Page AUR" "Retour") in
                "Mettre à jour $name") upgrade_in_term "paru -S $name" ;;
                "Page AUR") KEEP_OPEN=0; open "https://aur.archlinux.org/packages/$name" ;;
            esac ;;
        repo:*)
            # un paquet des dépôts seul = mise à jour partielle (non supportée par Arch : risque de casser
            # des dépendances) → on propose la mise à jour complète
            case $(ask "$name : paquet des dépôts, se met à jour avec tout le système" "Tout mettre à jour" "Page du paquet" "Retour") in
                "Tout mettre à jour") KEEP_OPEN=0; qb updates upgrade ;;
                "Page du paquet") KEEP_OPEN=0; open "https://archlinux.org/packages/?q=$name" ;;
            esac ;;
        *) KEEP_OPEN=0 ;;
    esac
}
