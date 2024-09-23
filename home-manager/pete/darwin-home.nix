{
  inputs,
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

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
