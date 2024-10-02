{
  inputs,
  pkgs,
  build_target,
  ...
}: {
  imports = [
    ./modules/cross-platform/alacritty-config.nix
    ./modules/cross-platform/git-config.nix
    ./modules/linux/bash-config.nix
    ./modules/linux/crypto.nix
    ./modules/linux/firefox-config.nix
    ./modules/linux/games.nix
    ./modules/linux/hyprland-config.nix
    ./modules/linux/media-tools.nix
    ./modules/linux/messengers.nix
    ./modules/linux/misc-tools.nix
    ./modules/linux/office-cloud.nix
    ./modules/linux/pen-tools.nix
    ./modules/linux/rofi-theme.nix
    ./modules/linux/theme-style.nix
    ./modules/linux/tmux-config.nix
    ./modules/linux/waybar-config.nix
  ];
  nixpkgs = {
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  fonts.fontconfig.enable = true;

  home = {
    username = "pete";
    homeDirectory = "/home/pete";
    packages =
      [
        inputs.nixvim.packages.${build_target.system}.default
      ]
      ++ (with pkgs; [
        fd
        fastfetch
        python311Packages.base58
        ripgrep
        xdg-user-dirs
      ]);
  };

  programs = {
    home-manager.enable = true;
    fzf.enable = true;
    bat = {
      enable = true;
    };
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
        color_theme = "nord";
      };
    };
    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    zoxide = {
      enable = true;
    };
    firefox = {
      enable = true;
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  services = {
    dunst = {
      enable = true; # Enable dunst notification daemon
      settings = {
        global = {
          corner_radius = 10;
          background = "#1f2335";
        };
      };
    };
    ssh-agent.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
