{ pkgs, lib, ... }:
{
  programs.zsh =
    let
      earlyInit =
        lib.mkOrder 500 # sh
          ''
            # early init
            # Ignore unsafe directory warnings from Darwin
            ZSH_DISABLE_COMPFIX="true"
          '';

      profileInit =
        lib.mkOrder 1000 # sh
          ''
            # profile init
            # Show fastfetch at login but not for every new TMUX pane/window
            if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
            	export FASTFETCH_EXECUTED=1
            	command -v ${pkgs.fastfetch}/bin/fastfetch &> /dev/null &&
            	${pkgs.fastfetch}/bin/fastfetch
            fi
          '';
    in
    {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = false;
      syntaxHighlighting.enable = true;
      defaultKeymap = "viins";
      shellAliases = {
        lsc = "lsd --classic"; # For annoying colors on SMB/NFS mounts
        wl-copy = "pbcopy"; # I use Wayland too much to remember the pb clip cmds
        wl-paste = "pbpaste";
        cd = "z";
      };
      sessionVariables = {
        EDITOR = "nvim";
      };
      oh-my-zsh = {
        enable = true;
        plugins = [
          "docker"
          "docker-compose"
          "colored-man-pages"
          "git"
          "ssh-agent"
          "vi-mode"
        ];
        theme = "robbyrussell";
        extraConfig =
          #Import ssh key TODO: make less imperative
          ''
            zstyle :omz:plugins:ssh-agent identities pete3n
          '';
      };
      initContent = lib.mkMerge [
        earlyInit
        profileInit
      ];
    };
}
