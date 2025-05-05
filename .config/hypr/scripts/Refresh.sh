#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
  if [ -e "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
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
xsettingsd &

# Kill already running processes
_ps=(waybar rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done
# reload openrgb
pkill -f OpenWal.py && python3 $HOME/.config/hypr/Openrgb/OpenWal.py

# added since wallust sometimes not applying
killall -SIGUSR2 waybar
killall -SIGUSR2 swaync

# quit ags & relaunch ags
ags -q && ags &

# some process to kill
for pid in $(pidof waybar rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
done

#Restart waybar
sleep 1
waybar &

# relaunch swaync
sleep 0.5
swaync >/dev/null 2>&1 &

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
  ${UserScripts}/RainbowBorders.sh &
fi

# Vérifier si Spotify est en cours d'exécution
if pidof spotify >/dev/null; then
  # Spotify est déjà en cours d'exécution
  spicetify refresh -n

  # Attendre un peu pour que les changements soient appliqués
  sleep 0.5

  # Envoyer Ctrl+Shift+R à la fenêtre Spotify existante
  # Vous pouvez utiliser hyprctl pour cela comme mentionné précédemment
  SPOTIFY_WINDOW=$(hyprctl clients | grep -B 1 "Spotify" | grep "Window" | awk '{print $2}')
  if [ -n "$SPOTIFY_WINDOW" ]; then
    hyprctl dispatch focuswindow "address:$SPOTIFY_WINDOW"
    hyprctl dispatch key "CTRL SHIFT R"
  fi
else
  # Spotify n'est pas en cours d'exécution, mettre à jour les fichiers de configuration sans lancer Spotify
  # Vous pouvez utiliser une commande qui met à jour uniquement les fichiers sans lancer l'application
  # Par exemple, on pourrait utiliser une commande spicetify qui ne lance pas Spotify ou juste mettre à jour les fichiers manuellement
  echo "Spotify n'est pas en cours d'exécution, mise à jour des fichiers de configuration uniquement."
  # Mettre à jour les fichiers de configuration (à adapter selon votre configuration)
  # Par exemple, vous pourriez copier les fichiers de thème générés par Wallust dans le dossier de thème de Spicetify
fi

# Notifier l'utilisateur
#notify-send "Spotify thème" "Les couleurs ont été mises à jour. Appuyez sur Ctrl+Shift+R dans Spotify pour les appliquer."

exit 0
