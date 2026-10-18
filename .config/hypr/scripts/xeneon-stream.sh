#!/bin/bash
# Récupère l'URL active de Zen via xdotool
URL=$(xdotool getactivewindow getwindowname | grep -oP 'https?://[^ ]+' || echo "")

if [ -z "$URL" ]; then
    # Si pas d'URL détectée, demande via zenity
    URL=$(zenity --entry --title="Xeneon Stream" --text="URL du stream :")
fi

mpv --video-aspect-override=2560:720 --fs --screen=1 "$URL" &
