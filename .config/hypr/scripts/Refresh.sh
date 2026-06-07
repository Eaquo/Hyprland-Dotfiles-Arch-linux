#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing, waybar, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
LOGDIR="$HOME/.config/quickshell/rgb-launcher/modules/script"
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
    if [ -e "$1" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}
# 1. Se placer dans le dossier du thème et compiler
cd ~/.themes/gtk || exit 1
npm run build

# 2. Sauvegarder le thème actuel et changer temporairement
CURRENT_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")
gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark-BL-LB' # Un thème sûr

# 3. Attendre un peu pour éviter les crashs
sleep 0.5

# 4. Appliquer le nouveau thème GTK
gsettings set org.gnome.desktop.interface gtk-theme "$CURRENT_THEME"

# 5. Relancer xsettingsd pour forcer l'application des changements
killall xsettingsd &>/dev/null
sleep 0.2
xsettingsd & disown

# reload openrgb
SEQ=$(cat $LOGDIR/sequence.txt)
pkill -f OpenRGB_Controller_Watch.py
# added since wallust sometimes not applying
killall -SIGUSR2 swaync

# some process to kill
for pid in $(pidof rofi swaync swaybg); do
    kill -SIGUSR1 "$pid"
done

# relaunch swaync
sleep 0.5
swaync > /dev/null 2>&1 &

python "$LOGDIR/OpenRGB_Controller_Watch.py" &

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    ${UserScripts}/RainbowBorders.sh &
fi

# Update Windsurf colors from wallust palette
python3 /home/florian/.config/wallust/hooks/windsurf-theme.py &

# Regenerate matugen colors if enabled in game launcher config
LAUNCHER_CONFIG="$HOME/.config/quickshell/game-launcher/config.toml"
if grep -q 'use_matugen\s*=\s*true' "$LAUNCHER_CONFIG" 2>/dev/null; then
    WALLPAPER=$(swww query | grep "$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')" | sed 's/.*image: //')
    if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
        matugen image "$WALLPAPER" --source-color-index 0 &
    fi
fi

exit 0
