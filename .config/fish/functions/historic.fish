# Rechercher dans l'historique avec fzf
function fh
    history | fzf --tac --no-sort | read -l cmd
    and commandline -r $cmd
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
   bind -Minsert ! __history_previous_command
   bind -Minsert '$' __history_previous_command_arguments
else
   bind ! __history_previous_command
   bind '$' __history_previous_command_arguments
end

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