# This file contains unique username based configuration options
{ config, ... }:
{
  programs.bash = {
    enableCompletion = true;
    shellAliases = {
      cd = "z";
      home-manager-rollback = "home-manager generations | fzf | awk -F '-> ' '{print \$2 \"/activate\"}'";
      screenshot = "grim";
      lsc = "lsd --classic";
    };
    initExtra =
      let
        ssh-private-key = "pete3n";
      in
      # bash
      ''
        #if command -v keychain > /dev/null 2>&1; then
        #	eval $(keychain --eval --nogui ${ssh-private-key} --quiet);
        #fi

        set -o vi
      '';

    profileExtra =
      # bash
      ''
        export EDITOR=nvim
        if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
        	command -v fastfetch &> /dev/null && fastfetch
        	export FASTFETCH_EXECUTED=1
        	echo
        	ip link
        	echo
        	ip -br a
        	echo
        fi
        # Workaround for xdg.userDirs bug always being set to false
        source "${config.home.homeDirectory}/.config/user-dirs.dirs"
      '';
  };
}
