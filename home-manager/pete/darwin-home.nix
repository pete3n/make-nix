{
  inputs,
  outputs,
  lib,
  build_target,
  pkgs,
  ...
}: {
  # import sub modules
  imports = [
    ./modules/shared/alacritty-config.nix
    ./modules/darwin/tmux-config.nix
    ./modules/darwin/profile-config.nix
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  programs = {
    home-manager.enable = true;
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
    fastfetch.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    lsd = {
      enable = true;
      enableAliases = true;
    };
    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
        color_theme = "nord";
      };
    };

    bash.enable = false;
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = false;
      syntaxHighlighting.enable = true;
      defaultKeymap = "viins";
      profileExtra =
        /*
        bash
        */
        ''
              	export EDITOR=nvim

          # Show fastfetch at login
          	if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
            	export FASTFETCH_EXECUTED=1
              command -v fastfetch &> /dev/null && fastfetch
            fi
        '';

      initExtra =
        /*
        bash
        */
        ''
          alias ls=lsd
          alias lsc='lsd --classic'
        '';
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
    username = "pete";
    homeDirectory = "/Users/pete";

    packages =
      [
        inputs.nixvim.packages.x86_64-darwin.default
      ]
      ++ (with pkgs; [
        fastfetch
      ]);

    sessionVariables = {
      EDITOR = "nvim";
    };

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "24.05";
  };
}
