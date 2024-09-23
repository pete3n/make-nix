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
    ./modules/darwin/alacritty-config.nix
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

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
    fzf.enable = true;
    zoxide.enable = true;
    bat.enable = true;

    # Show neofetch at login
    zsh = {
      enable = true;
      profileExtra =
        /*
        bash
        */
        ''
          export EDITOR=nvim
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
          bindkey -v
          bindkey ^R history-incremental-search-backward
          bindkey ^S history-incremental-search-forward
          alias ls=lsd
          alias lsc='lsd --classic'
        '';
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
        lsd
      ]);

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
