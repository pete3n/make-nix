{
  inputs,
  outputs,
  pkgs,
  build_target,
  ...
}:
{
  imports = builtins.attrValues outputs.homeManagerModules ++ [
    ./home-imports/cross-platform/alacritty-config.nix
    ./home-imports/cross-platform/git-config.nix
    ./home-imports/linux/bash-config.nix
    ./home-imports/linux/crypto.nix
    ./home-imports/linux/firefox-config.nix
    ./home-imports/linux/games.nix
    ./home-imports/linux/hyprland-config.nix
    ./home-imports/linux/media-tools.nix
    ./home-imports/linux/messengers.nix
    ./home-imports/linux/misc-tools.nix
    ./home-imports/linux/office-cloud.nix
    ./home-imports/linux/pen-tools.nix
    ./home-imports/linux/rofi-theme.nix
    ./home-imports/linux/theme-style.nix
    ./home-imports/linux/tmux-config.nix
    ./home-imports/linux/waybar-config.nix
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
      [ inputs.nixvim.packages.${build_target.system}.default ]
      ++ (with pkgs; [
        fd
        python311Packages.base58
        ripgrep-all # rg with PDF, office doc, compress file support
        xdg-user-dirs
      ]);
  };

  programs = {
    home-manager.enable = true;
    wallpaper-scripts = {
      enable = true;
      os = "linux";
    };

    # Better cat
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batman
        batgrep
        batwatch
      ];
    };
    # Better top resource monitor
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
        color_theme = "nord";
      };
    };
    # LSDeluxe improved ls command
    lsd = {
      enable = true;
      enableAliases = true;
    };
    # Fastfetch neofetch replacement
    fastfetch = {
      enable = true;
    };
    # Fuzzy finder
    fzf = {
      enable = true;
      enableBashIntegration = true;
    };
    # Recursive grep
    ripgrep = {
      enable = true;
    };
    # Yazi cli file manager
    yazi = {
      enable = true;
      enableBashIntegration = true;
    };
    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
      enableBashIntegration = true;
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
