function cd_fuzzy_suggest
    set -l tokens (commandline -opc)
    set -l token (commandline -ct)  # ce qui est tapé après cd

    set -l base "."

    # Si on a commencé à taper un chemin
    if test -n "$token"
        # Enlever le / final et espaces
        set base (string trim -r -c '/' "$token")

        # Si le dossier existe → fuzzy dedans
        if test -d "$base"
            # OK, on part de là
        else if test -d (dirname "$base")
            # Le parent existe → fuzzy dans le parent
            set base (dirname "$base")
        else
            # Rien n'existe → fallback sur courant
            set base "."
        end
    end

    # Maintenant fuzzy depuis $base
    set -l state "/tmp/cdfuzzy_$fish_pid.state"
    echo "$base" > "$state"

    set -l dirs ".." (eza -1 -a --only-dirs "$base" 2>/dev/null | string trim -r -c '/')
    or set -l dirs ".." (ls -1 -d "$base"/* 2>/dev/null | string trim -r -c '/')

    if test (count $dirs) -le 1
        rm -f "$state"
        return
    end

    set -l result (
        begin
            echo ".."
            eza -1 -a --only-dirs "$base" 2>/dev/null
        end | fzf \
            --reverse \
            --height 40% \
            --ansi \
            --no-info \
            --prompt "📂 cd depuis $base : " \
            --pointer " " \
            --header "→/Tab | ←/Shift-Tab | Entrée" \
            --color "pointer:#71ffee,prompt:#71ffee,border:#6272a4,header:#71ffee,info:#71ffee" \
            --border=rounded \
            --preview "
                set cur (cat $state)
                if test {} = '..'
                    set p (dirname \"\$cur\")
                else
                    set p \"\$cur/{}\"
                end
                echo \"📁 \$p\"
                echo
                eza -la -a --color=always --icons --group-directories-first \"\$p\" 2>/dev/null
            " \
            --preview-window "right:55%:wrap" \
            --bind "enter:execute-silent(set nxt {}; set cur (cat $state); if test \"\$nxt\" = '..'; set nd (dirname \"\$cur\"); else; set nd \"\$cur/\$nxt\"; end; echo \"\$nd\" > $state)+accept" \
            --bind "right:execute-silent(set nxt {}; set cur (cat $state); if test \"\$nxt\" = '..'; set nd (dirname \"\$cur\"); else; set nd \"\$cur/\$nxt\"; end; test -d \"\$nd\" && echo \"\$nd\" > $state)+reload(echo ..; eza -1 --only-dirs (cat $state) 2>/dev/null)" \
            --bind "tab:execute-silent(set nxt {}; set cur (cat $state); if test \"\$nxt\" = '..'; set nd (dirname \"\$cur\"); else; set nd \"\$cur/\$nxt\"; end; test -d \"\$nd\" && echo \"\$nd\" > $state)+reload(echo ..; eza -1 --only-dirs (cat $state) 2>/dev/null)" \
            --bind "left:execute-silent(set cur (cat $state); set nd (dirname \"\$cur\"); echo \"\$nd\" > $state)+reload(echo ..; eza -1 --only-dirs (cat $state) 2>/dev/null)" \
            --bind "shift-tab:execute-silent(set cur (cat $state); set nd (dirname \"\$cur\"); echo \"\$nd\" > $state)+reload(echo ..; eza -1 --only-dirs (cat $state) 2>/dev/null)" \
            --select-1 --exit-0
    )

    set -l target (cat $state 2>/dev/null)
    rm -f $state

    if test -n "$target"
        commandline -f kill-whole-line
        commandline -r "cd $target"
        commandline -f repaint
        commandline -f execute
    end
end