{ pkgs, lib, makeNixAttrs, ... }:
{
  ##########################################################################
  #
  #  Install all apps and packages here.
  #
  #  NOTE: Your can find all available options in:
  #    https://daiderd.com/nix-darwin/manual/index.html
  #
  # TODO Fell free to modify this file to fit your needs.
  #
  ##########################################################################

  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
  environment.systemPackages = with pkgs; [
    git
    tldr
    magic-wormhole-rs
    ripgrep
    home-manager
    skhd
    element-desktop
  ];

  # Import other system packages and configuration options
  imports = [
    ./yabai.nix
    ./skhd.nix
  ];

  homebrew = lib.mkIf makeNixAttrs.useHomebrew {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # 'zap': uninstalls all formulae(and related files) not listed here.
      # cleanup = "zap";
    };

    # `brew install`
    # TODO Feel free to add your favorite apps here.
    brews = [
    ];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
    casks = [
    ];
  };
}
