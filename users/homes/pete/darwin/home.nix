{
  inputs,
  lib,
  pkgs,
  makeNixAttrs,
  homeModules,
  ...
}:
# "Tags" allow customizable user-based configuration at evaluation time similar
# to specialisations for the system.
# Simply add a tag string to the list of linuxTags, and then define and import
# list for it in tagMap.
# Even though we are building for users, we can still customize some
# system based configuration and demonstrate the power of Nix to provide
# a declarative outcome: get a working Hyprland WM, regardless of
# if we are using NixOS or a different Linux distribution.
let
  darwinTags = [ ];

  availableTags = builtins.filter (tag: builtins.elem tag darwinTags) makeNixAttrs.tags;

  tagImportMap = {
  };

  tagImports = lib.flatten (builtins.map (tag: tagImportMap.${tag}) availableTags);
in
{
  imports =
    builtins.attrValues homeModules
    ++ [
      ../cross-platform/alacritty-config.nix
      ../cross-platform/git-config.nix
      ../cross-platform/cli-programs.nix
      ./firefox-config.nix
      ./tmux-config.nix
      ./zsh-config.nix
    ]
    ++ tagImports;

  nixpkgs = {
    overlays = [
      inputs.nixpkgs-firefox-darwin.overlay
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  programs = {
    home-manager.enable = true;
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
      [ inputs.nixvim.packages.${makeNixAttrs.system}.default ]
      ++ (with pkgs; [
        local.yubioath-darwin
        python312Packages.base58
      ]);
  };
}
