#!/bin/bash
TOUCH_DEVICE="/dev/input/event2"

# Valeurs max du touchscreen (vues dans evtest)
TOUCH_MAX_X=16383
TOUCH_MAX_Y=9599

# Position et taille du Xeneon sur ton bureau virtuel
MONITOR_X=0
MONITOR_Y=1440
MONITOR_WIDTH=2560
MONITOR_HEIGHT=720

touch_x=""
touch_y=""

process_touch_event() {
    if echo "$line" | grep -q "ABS_MT_POSITION_X.*value"; then
        touch_x=$(echo "$line" | grep -o "value [0-9]*" | cut -d' ' -f2)
    fi

    if echo "$line" | grep -q "ABS_MT_POSITION_Y.*value"; then
        touch_y=$(echo "$line" | grep -o "value [0-9]*" | cut -d' ' -f2)
    fi

    if echo "$line" | grep -q "BTN_TOUCH.*value 1"; then
        if [ -n "$touch_x" ] && [ -n "$touch_y" ]; then
            screen_x=$(( MONITOR_X + touch_x * MONITOR_WIDTH / TOUCH_MAX_X ))
            screen_y=$(( MONITOR_Y + touch_y * MONITOR_HEIGHT / TOUCH_MAX_Y ))

            cursor_pos=$(hyprctl cursorpos)
            saved_x=$(echo "$cursor_pos" | cut -d',' -f1 | tr -d ' ')
            saved_y=$(echo "$cursor_pos" | cut -d',' -f2 | tr -d ' ')

            hyprctl eval 'hl.dsp.exec_cmd("hyprctl dispatch focusmonitor DP-2")'
            hyprctl dispatch movecursor $screen_x $screen_y
            sleep 0.05
            ydotool click 0xC0
            sleep 0.05
            hyprctl dispatch movecursor $saved_x $saved_y
        fi
    fi
}

evtest "$TOUCH_DEVICE" | while read -r line; do
    process_touch_event "$line"
done

