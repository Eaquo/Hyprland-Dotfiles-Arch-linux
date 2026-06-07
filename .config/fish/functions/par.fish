# Rechercher et éditer des fichiers de config
function par
    set -lx DISABLE_FASTFETCH 1
    env SHELL=/bin/bash bash --norc --noprofile -c '
        command -v yay &> /dev/null || { echo "yay non installé"; exit 1; }
        command -v fzf &> /dev/null || { echo "fzf non installé"; exit 1; }

        TMPDIR=$(mktemp -d /tmp/yaypreview-XXXX)
        MODE_FILE=$(mktemp /tmp/pkg-mode-XXXX)
        echo "install" > $MODE_FILE

        trap "rm -rf \$TMPDIR \$MODE_FILE" EXIT

        while true; do
            MODE=$(cat $MODE_FILE)

            if [ "$MODE" = "install" ]; then
                RESULT=$(yay -Slq | \
                fzf --multi \
                    --style full \
                    --header-first \
                    --reverse \
                    --input-label " Input Installer" \
                    --header="TAB: sélection | ENTER: installer | Ctrl-A: Mode suppression" \
                    --bind "ctrl-a:execute-silent(echo remove > $MODE_FILE)+abort" \
                    --color "input-border:#19ff06,input-label:#ffcccc" \
                    --pointer="" \
                    --color "pointer:#19ff06" \
                    --prompt=" yay -Slq: " \
                    --preview "
                        pkgname={1};
                        yay -G \$pkgname --noedit --builddir \$TMPDIR &> /dev/null
                        if [ -f \$TMPDIR/\$pkgname/PKGBUILD ]; then
                            bat --style=plain --paging=never \$TMPDIR/\$pkgname/PKGBUILD 2>/dev/null || cat \$TMPDIR/\$pkgname/PKGBUILD
                        else
                            yay -Sii \$pkgname
                        fi
                    " \
                    --preview-window=down:40%)

                if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
                    [ -n "$RESULT" ] && yay -S --noconfirm $RESULT </dev/tty
                    break
                elif [ "$(cat $MODE_FILE)" = "install" ]; then
                    break
                fi
            else
                RESULT=$(pacman -Qq | \
                fzf --multi \
                    --style full \
                    --preview "pacman -Qi {}" \
                    --preview-window=down:40% \
                    --header-first \
                    --reverse \
                    --input-label " Input Remove" \
                    --pointer="" \
                    --color "pointer:#ff0098" \
                    --prompt=" pacman -Qq: " \
                    --header="TAB: sélection | ENTER: désinstaller | Ctrl-A: Mode installation" \
                    --color "input-border:#ff0098,input-label:#ffcccc" \
                    --bind "ctrl-a:execute-silent(echo install > $MODE_FILE)+abort")

                if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
                    [ -n "$RESULT" ] && yay -Rns --noconfirm $RESULT </dev/tty
                    break
                elif [ "$(cat $MODE_FILE)" = "remove" ]; then
                    break
                fi
            fi
        done
    '
end