set -g fish_greeting
set VIRTUAL_ENV_DISABLE_PROMPT "1"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x SHELL /usr/bin/fish

export PATH="$PATH:~/.millennium/ext/bin"
set -U fish_user_paths ~/.millennium/ext/bin $fish_user_paths

## Export variable need for qt-theme

if type "qtile" >> /dev/null 2>&1
   set -x QT_QPA_PLATFORMTHEME "qt5ct"
end

# Set settings for https://github.com/franciscolourenco/done

set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Ne pas exécuter neofetch si la variable no_neofetch est définie
#if not set -q no_neofetch
#    neofetch
#end
# Apply .profile: use this to put fish compatible .profile stuff in

if test -f ~/.fish_profile
   source ~/.fish_profile
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
   if not contains -- ~/.local/bin $PATH
      set -p PATH ~/.local/bin
   end
end

# Add depot_tools to PATH

if test -d ~/Applications/depot_tools
   if not contains -- ~/Applications/depot_tools $PATH
      set -p PATH ~/Applications/depot_tools
   end
end

## Starship prompt

if status --is-interactive
   source ("/usr/bin/starship" init fish --print-full-init | psub)
end

## Advanced command-not-found hook

# source /usr/share/doc/find-the-command/ftc.fish

## Functions

# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang

function __history_previous_command
   switch (commandline -t)
   case "!"
      commandline -t $history[1]; commandline -f repaint
   case "*"
      commandline -i !
   end
end

function __history_previous_command_arguments
   switch (commandline -t)
   case "!"
      commandline -t ""
      commandline -f history-token-search-backward
   case "*"
      commandline -i '$'
   end
end

# Fonction pour rechercher et installer des paquets avec fzf
function par
    set -lx DISABLE_NEOFETCH 1
    env SHELL=/bin/bash bash --norc --noprofile -c '
        # Vérifier que les commandes nécessaires existent
        command -v yay &> /dev/null || { echo "yay non installé"; exit 1; }
        command -v fzf &> /dev/null || { echo "fzf non installé"; exit 1; }

        TMPDIR=$(mktemp -d /tmp/yaypreview-XXXX)

        # Nettoyage automatique même en cas d'\''erreur
        trap "rm -rf \$TMPDIR" EXIT

        yay -Slq | \
        fzf --multi \
            --header="TAB: sélection | ENTER: installer | Ctrl-/: toggle preview" \
            --preview "
                pkgname={1};
                yay -G \$pkgname --noedit --builddir \$TMPDIR &> /dev/null
                if [ -f \$TMPDIR/\$pkgname/PKGBUILD ]; then
                    bat --style=plain --paging=never \$TMPDIR/\$pkgname/PKGBUILD 2>/dev/null || cat \$TMPDIR/\$pkgname/PKGBUILD
                else
                    yay -Sii \$pkgname
                fi
            " \
            --preview-window=down:40% \
        | xargs -ro yay -S
    '
end

# Supprimer des paquets avec fzf
function prm
    env SHELL=/bin/bash bash --norc --noprofile -c '
        command -v fzf &> /dev/null || { echo "fzf non installé"; exit 1; }

        pacman -Qq | \
        fzf --multi \
            --preview "pacman -Qi {}" \
            --preview-window=right:60% \
            --header="TAB: sélection | ENTER: désinstaller" \
        | xargs -ro sudo pacman -Rns
    '
end

# Naviguer dans les dossiers récents avec fzf + zoxide
function j
    set -l result (zoxide query -l | fzf --height=40% --reverse)
    and cd $result
end

# Rechercher dans l'historique avec fzf
function fh
    history | fzf --tac --no-sort | read -l cmd
    and commandline -r $cmd
end

# Rechercher et éditer des fichiers de config
function conf-edit
    set -l config_dirs ~/.config ~/
    fd . $config_dirs --type f --hidden --exclude .git | \
    fzf --preview "bat --color=always {}" \
        --preview-window=right:60% | \
    read -l file

    if test -n "$file"
        if set -q EDITOR
            $EDITOR $file
        else
            nvim $file
        end
    end
end

set -gx EDITOR nvim
set -gx VISUAL nvim

# Gérer les services systemd avec fzf
function sctl
    set -l service (systemctl list-units --all --type=service --no-pager | \
        tail -n +2 | \
        fzf --header="Choisir un service" | \
        awk '{print $1}')

    if test -n "$service"
        set -l action (printf "start\nstop\nrestart\nenable\ndisable\nstatus" | \
            fzf --header="Action pour $service")

        if test -n "$action"
            sudo systemctl $action $service
        end
    end
end

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

# Changer d thème wallust/wallpaper avec fzf
function wall
    set -l wallpaper (fd . ~/Pictures/Wallpapers --type f | \
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
    set -l cache_size (du -sh /var/cache/pacman/pkg | awk '{print $1}')
    echo "Taille du cache: $cache_size"

    set -l action (printf "Garder 3 versions\nGarder 1 version\nTout supprimer\nAnnuler" | fzf)

    switch $action
        case "Garder 3 versions"
            sudo paccache -rk3
        case "Garder 1 version"
            sudo paccache -rk1
        case "Tout supprimer"
            sudo pacman -Scc
    end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
   bind -Minsert ! __history_previous_command
   bind -Minsert '$' __history_previous_command_arguments
else
   bind ! __history_previous_command
   bind '$' __history_previous_command_arguments
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

alias fgrep 'ugrep -F --color=auto'
alias grubup 'sudo update-grub'
alias hw 'hwinfo --short'                          # Hardware Info
alias ip 'ip -color'
alias psmem 'ps auxf | sort -nr -k 4'
alias psmem10 'ps auxf | sort -nr -k 4 | head -10'
alias rmpkg 'sudo pacman -Rdd'
alias tarnow 'tar -acf '
alias untar 'tar -zxvf '
alias upd '/usr/bin/garuda-update'
alias vdir 'vdir --color=auto'
alias wget 'wget -c '
alias conf 'cd ~/.config'
alias home 'cd ~/'
alias check 'ncdu'
alias homelab 'ssh root@192.168.1.175 -p 10'
# Get fastest mirrors

alias mirror 'sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist'
alias mirrora 'sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist'
alias mirrord 'sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist'
alias mirrors 'sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist'

# Help people new to Arch

alias apt 'man pacman'
alias apt-get 'man pacman'
alias please 'sudo'
alias tb 'nc termbin.com 9999'
alias helpme 'echo "To print basic information about a command use tldr <command>"'
alias pacdiff 'sudo -H DIFFPROG=meld pacdiff'

# Get the error messages from journalctl

alias jctl 'journalctl -p 3 -xb'

abbr media-org 'cd ~/recovery-analysis; and source venv/bin/activate.fish'
# Recent installed packages

# Neovim
# alias nvim='wezterm start -- nvim'
alias nv 'MANGOHUD=0 nvim'
alias nvimfull 'MANGOHUD=0 wezterm start nvim'
#alias nvim 'MANGOHUD=0 wezterm start nvim'
alias hypr 'hyprctl reload'
alias up 'sudo pacman -Suy'
alias clock 'tty-clock -c -s -b -f "%H:%M:%S" -C 3 -B'

alias rip 'expac --timefmt="%Y-%m-%d %T" "%l\t%n %v" | sort | tail -200 | nl'

function no_error_output
   $argv 2> /dev/null
end


function parameter_is_provided
   set -q argv[1]
end


function command_failed
   test $status -eq 1
end


function newline
   echo ""
end


function updated
   test 2400 -ge (path mtime --relative /var/log/pacman.log) && # Prevents that updates run even if the system has been updated recently.
   string match -rq "System is updated" (tail -2 /var/log/pacman.log) # Prevents that canceled updates count as complete updates.
end


function log_update
   echo [(date +"%Y-%m-%dT%T%z")] [FISH] System is updated  | sudo tee -a /var/log/pacman.log >/dev/null
end


# add and friends


function remove --wraps "pacman -Runs"
   sudo pacman -Runs --noconfirm $argv
   if command_failed
      sudo pacman -Rcns $argv
      if not command_failed
         echo "You can always rollback to a previous state of your system, simply by selecting 'Garuda Snapshots' in the boot menu."
      end
   end
end


function commit
   if parameter_is_provided $argv
      git add .
      git commit -am "$argv"
      git push
   else
      newline
      echo "Please provide a commit message:" && newline
      set_color blue; printf "commit "; set_color green; printf "\"this is a commit message\"";
      set_color normal
   end
end

## Import colorscheme from 'wal' asynchronously
if type "wallust" >> /dev/null 2>&1
   cat ~/.cache/wallust/sequences
end

## Run paleofetch if session is interactive
if status --is-interactive
   clear && fastfetch
end

zoxide init fish | source

function updated
   test 2400 -ge (path mtime --relative /var/log/pacman.log) && # Prevents that updates run even if the system has been updated recently.
   string match -rq "System is updated" (tail -2 /var/log/pacman.log) # Prevents that canceled updates count as complete updates.
end


function log_update
   echo [(date +"%Y-%m-%dT%T%z")] [FISH] System is updated  | sudo tee -a /var/log/pacman.log >/dev/null
end


# add and friends


function add --wraps "paru -S"
   if not updated
      update --skip-mirrorlist --noconfirm &&
      paru -Sua --skipreview --useask --noconfirm &&
      sudo pkgfile --update &&
      log_update &&
      add $argv
   else
      newline
      set_color green; echo "System is up to date."
      set_color normal && newline

      if parameter_is_provided $argv
         no_error_output sudo pacman -S --noconfirm $argv &&
         log_update
         if command_failed
            no_error_output paru -S --aur --skipreview --useask --noconfirm $argv &&
            log_update
            if command_failed
               newline && search $argv
            end
         end
      end
   end
end


function search --wraps "paru -Ss"
   set -l success no
   paru -Ss --aur $argv; and set success yes; and newline
   pacman -Ss $argv; and set success yes; and newline
   no_error_output pacman -Qi $argv; and set success yes
   if test $success = no
      read -p 'set_color green; echo -n "$prompt No results found. Do you like to look up package files? [Y/n]: "; set_color normal' -l confirm
      switch $confirm
      case Y y ''
         pkgfile -vri $argv
      case N n
         return 1
      end
   end
end


function remove --wraps "pacman -Runs"
   sudo pacman -Runs --noconfirm $argv
   if command_failed
      sudo pacman -Rcns $argv
      if not command_failed
         echo "You can always rollback to a previous state of your system, simply by selecting 'Garuda Snapshots' in the boot menu."
      end
   end
end


function commit
   if parameter_is_provided $argv
      git add .
      git commit -am "$argv"
      git push
   else
      newline
      echo "Please provide a commit message:" && newline
      set_color blue; printf "commit "; set_color green; printf "\"this is a commit message\"";
      set_color normal
   end
end

## Import colorscheme from 'wal' asynchronously
if type "wallust" >> /dev/null 2>&1
   cat ~/.cache/wallust/sequences
end

## Run paleofetch if session is interactive
if status --is-interactive
   neofetch
end


# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/florian/.lmstudio/bin
# End of LM Studio CLI section

