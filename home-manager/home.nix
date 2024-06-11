# This is the base level home configuration that is applied for all users
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  homeManagerModules,
  ...
}: {
  # You can import other home-manager modules that should be used by all
  # users here. Other modules are passed by the flake with homeManagerModules
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  fonts.fontconfig.enable = true;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # Shared user packages
  home.packages = with pkgs; [
    fd # Fast find altenative
    fastfetch
    python311Packages.base58
    ripgrep # Simplified recursive grep utility
  ];

  programs.home-manager.enable = true;

  # Fuzzy finder integration - will change your life
  programs.fzf.enable = true;

  # A better cat
  programs.bat = {
    enable = true;
  };

  # A smarter cd
  programs.zoxide = {
    enable = true;
  };

  programs.firefox = {
    enable = true;
  };

  # Show neofetch at login
  programs.bash = {
    enable = true;
    profileExtra = ''
        if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
        	export FASTFETCH_EXECUTED=1
        	command -v fastfetch &> /dev/null && fastfetch
        	echo
        	ip link
        	echo
        	ip -br a
        	echo
      # Start the SSH agent if not already running
      if [ -z "$SSH_AUTH_SOCK" ]; then
      		eval "$(ssh-agent -s)"
      fi

      # Add SSH key
      ssh-add ~/.ssh/pete3n
        fi
    '';
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
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
