# This file contains unique username based configuration options
{
  config,
  pkgs,
  ...
}: {
  home = {
    username = "pete";
    homeDirectory = "/home/pete";
    packages = with pkgs; [
      xdg-user-dirs
    ];
  };

  xdg = {
    enable = true;
    userDirs = let
      appendToHomeDir = path: "${config.home.homeDirectory}/${path}";
    in {
      enable = true;
      documents = appendToHomeDir "documents";
      download = appendToHomeDir "downloads";
      music = appendToHomeDir "music";
      pictures = appendToHomeDir "pictures";
      publicShare = appendToHomeDir "public";
      templates = appendToHomeDir "templates";
      videos = appendToHomeDir "videos";
      extraConfig = {
        XDG_PROJECT_DIR = appendToHomeDir "projects";
        XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
        XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      };
    };
  };
  programs.git = {
    enable = true;
    userName = "pete3n";
    userEmail = "pete3n@protonmail.com";
    extraConfig = {
      core.editor = "nvim";
      #commit.gpgsign = true;
      #gpg.format = "ssh";
      #gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signer";
      #user.signingkey = "~/.ssh/pete3n.pub";
    };
  };

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
      '';

    profileExtra =
      /*
      bash
      */
      ''
            # User aliases
        alias screenshot=grim
            # Workaround for xdg.userDirs bug always being set to false
            source "${config.home.homeDirectory}/.config/user-dirs.dirs"
      '';
  };
}
