#!/bin/bash
# /* ---- 💫 Script Editor for Gamescope Scripts ---- */ ##
# Rofi menu for Quick Edit/View of Gamescope Game Scripts

# Define preferred text editor and terminal
edit=${EDITOR:-nvim}
tty=kitty

# Paths to scripts directory
SCRIPTS_DIR="$HOME/.config/hypr/scripts/GameScripts"
BASE_SCRIPT="Base_Script_Game"   # Script modèle à ne pas afficher dans la liste principale
UPDATE_SCRIPT="add-script.sh"    # Script de mise à jour à ne pas afficher dans la liste principale
NEW_GAME_SCRIPT="new-game"       # Assistant de création (gum) à ne pas afficher dans la liste

# Liste des scripts de jeu (exclut base, update, assistant et le dossier lib/)
list_games() {
    find "$SCRIPTS_DIR" -maxdepth 1 -type f -executable \
        ! -name "$BASE_SCRIPT" ! -name "$UPDATE_SCRIPT" ! -name "$NEW_GAME_SCRIPT" | sort
}

# Rofi theme
rofi_theme="$HOME/.config/rofi/config-edit-game.rasi"
msg="  Choose which game script to View or Edit ($SCRIPTS_DIR)"

# Function to display the menu options dynamically
menu() {
    # Get list of scripts, excluding base/update/assistant scripts
    script_files=$(list_games)
    # Count for numbering
    count=1
    
    # Generate menu with numbered entries
    for script in $script_files; do
        script_name=$(basename "$script")
        echo "$count. $script_name"
        ((count++))
    done   
    # Add options for special actions
    echo "$count. + Create new game script"
    ((count++))
    echo "$count. Edit base script template"
    ((count++))
    echo "$count. Run update script"
}

# Function to run the update script
run_update_script() {
    update_path="$SCRIPTS_DIR/$UPDATE_SCRIPT"
    
    if [[ -f "$update_path" && -x "$update_path" ]]; then
        $tty -e bash -c "$update_path; echo 'Press Enter to close'; read"
    else
        $tty -e bash -c "echo 'Update script not found or not executable!'; echo 'Press Enter to close'; read"
    fi
}

# Main function to handle menu selection
main() {
    # Check if scripts directory exists, create if not
    if [ ! -d "$SCRIPTS_DIR" ]; then
        mkdir -p "$SCRIPTS_DIR"
    fi
    
    # Get choice from rofi menu
    choice=$(menu | rofi -i -dmenu -config $rofi_theme -mesg "$msg")
    
    # Extract number and script name
    choice_num=$(echo "$choice" | cut -d. -f1)
    
    # Get the total number of game scripts
    script_count=$(list_games | wc -l)
    
    # Check if choice is to create a new script
    if [[ $choice_num -eq $((script_count + 1)) ]]; then
        # Lance l'assistant gum en une fois (nom + options + exports + symlink)
        # La fenêtre se ferme d'elle-même à la fin de l'assistant.
        $tty -e "$SCRIPTS_DIR/$NEW_GAME_SCRIPT"
        return
    fi
    
    # Check if choice is to edit the base script
    if [[ $choice_num -eq $((script_count + 2)) ]]; then
        base_script_path="$SCRIPTS_DIR/$BASE_SCRIPT"
        
        # Edit the base script
        $tty -e $edit "$base_script_path"
        return
    fi
    
    # Check if choice is to run the update script
    if [[ $choice_num -eq $((script_count + 3)) ]]; then
        run_update_script
        return
    fi
    
    # Handle regular script selection
    if [[ -n "$choice" ]]; then
        # Find the selected script
        script_files=$(list_games)
        
        # Initialize counter
        count=1
        
        # Find the file corresponding to the number
        for script in $script_files; do
            if [[ $count -eq $choice_num ]]; then
                # Open the script in editor
                $tty -e $edit "$script"
                break
            fi
            ((count++))
        done
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
    pkill rofi
fi

main
