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
    bash = {
      enable = true;
      profileExtra =
        /*
        bash
        */
        ''
          if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
          	command -v fastfetch &> /dev/null && fastfetch
          	export FASTFETCH_EXECUTED=1
          	echo
          	ip link
          	echo
          	ip -br a
          	echo
          		fi
        '';
    };
  };

  fonts.fontconfig.enable = true;
  ssh-agent.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "pete";
    homeDirectory = "/Users/pete";

    packages = [
      inputs.nixvim.packages.x86_64-darwin.default
    ];

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
