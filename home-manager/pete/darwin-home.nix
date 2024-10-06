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
    ./home-imports/darwin/firefox-config.nix
    ./home-imports/darwin/tmux-config.nix
    ./home-imports/darwin/zsh-config.nix
  ];

  nixpkgs = {
    overlays = [
      inputs.nixpkgs-firefox-darwin.overlay
      outputs.overlays.local-packages
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  programs = {
    home-manager.enable = true;
    wallpaper-scripts = {
      enable = true;
      os = "darwin";
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
    fastfetch.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    gpg.enable = true;
    # LSDeluxe improved ls command
    lsd = {
      enable = true;
      enableAliases = true;
    };
    # Recursive grep
    ripgrep = {
      enable = true;
    };
    # Yazi cli file manager
    yazi = {
      enable = true;
      enableZshIntegration = true;
    };
    # Zathura PDF viewer with VIM motions
    zathura = {
      enable = true;
    };
    # Zoxide better cd replacement with memory
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    starship = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  fonts.fontconfig.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "pete";
    homeDirectory = "/Users/pete";

    packages =
      [ inputs.nixvim.packages.${build_target.system}.default ]
      ++ (with pkgs; [
        local.yubioath-darwin
        python312Packages.base58
      ]);
  };
}
