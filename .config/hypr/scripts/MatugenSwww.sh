#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Matugen Colors (Material You) for current wallpaper

# Define the path to the swww cache directory
cache_dir="$HOME/.cache/swww/"

# Initialize a flag
ln_success=false

# Get current focused monitor
current_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')
echo $current_monitor

# Construct the full path to the cache file
cache_file="$cache_dir$current_monitor"
echo $cache_file

# Check if the cache file exists for the current monitor output
if [ -f "$cache_file" ]; then
    # Get the wallpaper path using swww query
    wallpaper_path=$(swww query | grep "$current_monitor" | sed 's/.*image: //')
    echo $wallpaper_path

    # symlink the wallpaper to the location Rofi can access
    if ln -sf "$wallpaper_path" "$HOME/.config/rofi/.current_wallpaper"; then
        ln_success=true
    fi

    # copy the wallpaper for wallpaper effects
    cp -r "$wallpaper_path" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
fi

# Check the flag before executing further commands
if [ "$ln_success" = true ]; then
    echo 'about to execute matugen'
    # Run matugen — picks most dominant color, no interactive prompt
    matugen image "$wallpaper_path" --source-color-index 0 &
fi
