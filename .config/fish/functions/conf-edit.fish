function conf-edit --description "Trouver et éditer un fichier de config avec preview images"
    if test "$PWD" = "$HOME"
        set -l config_dirs ~/.config ~/
    else
        set -l config_dirs $PWD
    end
    
    set -l file (
        fd . $config_dirs --type f --hidden --exclude .git | \
        fzf --style full \
            --border=rounded \
            --preview 'bash -c '\''
                file="{}"
                    bat --color=always --style=plain --line-range=:500 "$file" 2>/dev/null || cat "$file"
            '\''' \
            --preview-window=right:60%:wrap \
            --bind "ctrl-/:toggle-preview" \
            --bind "ctrl-y:execute-silent(echo {} | wl-copy)" \
            --header-first \
            --reverse \
            --header="ENTER: menu | Ctrl-Y: copier chemin | Ctrl-/: toggle preview" \
            --pointer=" " \
            --prompt=" Chercher: " \
            --color "pointer:#71ffee,prompt:#71ffee,border:#6272a4,header:#71ffee,info:#71ffee" \
    )
    
    # Si aucun fichier sélectionné, quitter
    if test -z "$file"
        return 0
    end
    
    # Menu d'actions
    set -l action (
        printf "Éditer\nVoir (lecture seule)\nCopier le chemin\nOuvrir le dossier" \
        | fzf --height=40% --header="Action pour: "(basename "$file")
    )
    
    switch "$action"
        case "Éditer"
            nvim "$file"
        case "Voir (lecture seule)"
            if string match -q -i -r '\.(jpg|jpeg|png|gif|webp|bmp|svg|tiff?)$' "$file"
                kitty +kitten icat "$file"
                read -P "Appuyez sur Entrée pour continuer..."
            else
                bat "$file"
            end
        case "Copier le chemin"
            echo "$file" | wl-copy
            echo "Chemin copié: $file"
        case "Ouvrir le dossier"
            cd (dirname "$file")
    end
end

