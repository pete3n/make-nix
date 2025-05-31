# NixOS Flake based on a Hyprland, Tmux, NeoVim workflow

## TODO:

- rofi - fix calc, clipmenu, mpc
- Home-manager rollback script: bash $(home-manager generations | fzf | awk -F '-> ' '{print $2 "/activate"}')
