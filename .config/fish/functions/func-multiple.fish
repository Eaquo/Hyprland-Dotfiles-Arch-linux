# Tuer un processus avec fzf
function kp
    ps aux | \
    fzf --header="TAB: sélection | ENTER: tuer" \
        --header-lines=1 \
        --multi | \
    awk '{print $2}' | \
    xargs -r kill -9
end

# Voir les logs avec fzf
function logs
    set -l log_file (fd . /var/log --type f --exclude "*.gz" | \
        fzf --preview "tail -50 {}")

    if test -n "$log_file"
        tail -f $log_file
    end
end

# Git checkout branch avec fzf
function gcb
    git branch --all | \
    grep -v HEAD | \
    fzf --preview="git log --oneline --graph --color=always {}" | \
    sed 's/^[* ]*//' | \
    xargs git checkout
end

# Recherche rapide dans le contenu des fichiers
function rg-fzf
    rg --color=always --line-number --no-heading --smart-case $argv | \
    fzf --ansi \
        --delimiter ':' \
        --preview 'bat --color=always --highlight-line {2} {1}' \
        --preview-window '+{2}/2'
end

# Changer de thème wallust/wallpaper avec fzf
function wall
    set -l wallpaper (fd . ~/Pictures/wallpapers --type f | \
        fzf --preview "kitty +kitten icat --clear --transfer-mode=memory --stdin=no --place=80x80@0x0 {}")

    if test -n "$wallpaper"
        wallust run $wallpaper
        # ou swww img $wallpaper --transition-type random
    end
end

# Bookmark rapide de dossiers
function mark
    pwd >> ~/.local/share/marks
end

function marks
    cat ~/.local/share/marks | \
    fzf | \
    read -l dir
    and cd $dir
end

# Nettoyer le cache pacman intelligemment
function pclean
    # Taille du cache avec sudo
    set -l cache_size (sudo du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')
    echo "Taille du cache: $cache_size"

    # Compter les paquets en cache
    set -l pkg_count (sudo find /var/cache/pacman/pkg -name "*.pkg.tar.zst" | wc -l)
    echo "Nombre de paquets en cache: $pkg_count"

    if test $pkg_count -eq 0
        echo "Le cache est vide ou déjà nettoyé !"
        return
    end

    set -l action (printf "Garder 3 versions\nGarder 1 version\nTout supprimer\nAnnuler" | \
        fzf --height=40% --header="Action pour le cache pacman")

    switch $action
        case "Garder 3 versions"
            sudo paccache -rvk3
        case "Garder 1 version"
            sudo paccache -rvk1
        case "Tout supprimer"
            read -P "Êtes-vous sûr de vouloir tout supprimer ? [o/N] " -l confirm
            if test "$confirm" = "o" -o "$confirm" = "O"
                sudo pacman -Scc --noconfirm
            end
        case "Annuler"
            echo "Opération annulée"
    end

    # Afficher la nouvelle taille
    if test "$action" != "Annuler"
        set -l new_size (sudo du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')
        echo "Nouvelle taille: $new_size"
    end
end

# Fish command history

function history
   builtin history --show-time='%F %T '
end

function backup --argument filename
   cp $filename $filename.bak
end

# Copy DIR1 DIR2

function copy
    if status is-interactive
        set count (count $argv | tr -d \n)
        if test "$count" = 2; and test -d "$argv[1]"
            set from (string trim --right --chars='/' -- $argv[1])
            set to $argv[2]
            command cp -r $from $to
        else
            command cp $argv
        end
    else
        command cp $argv
    end
end

# Cleanup local orphaned packages

function cleanup
   while pacman -Qdtq
      sudo pacman -R (pacman -Qdtq)
   end
end