# This file contains unique username based configuration options
{config, ...}: {
  programs.bash = {
    initExtra = let
      ssh-private-key = "pete3n";
    in
      /*
      bash
      */
      ''
        if command -v keychain > /dev/null 2>&1; then
        eval $(keychain --eval --nogui ${ssh-private-key} --quiet);
        fi

        set -o vi

        alias screenshot=grim
        alias ls=lsd
            alias lsc='lsd --classic'
      '';

    profileExtra =
      /*
      bash
      */
      ''
            export EDITOR=nvim
        # Workaround for xdg.userDirs bug always being set to false
        source "${config.home.homeDirectory}/.config/user-dirs.dirs"
      '';
  };
}
