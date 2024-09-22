{
  inputs,
  lib,
  pkgs,
  ...
}: {
  # import sub modules
  imports = [
    ../modules/home-manager/pete/alacritty-config.nix
    ../modules/home-manager/pete/tmux-config.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "pete";
    homeDirectory = "/Users/pete";

    packages = lib.mkAfter [
    	inputs.nixvim.packages.x86_64-darwin.default # Customized Neovim dev package
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
