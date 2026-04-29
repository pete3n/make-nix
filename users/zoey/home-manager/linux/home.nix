# Home-manager configuration
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
  linuxTags = [ "hyprland" ];

  availableTags = builtins.filter (tag: builtins.elem tag linuxTags) makeNixAttrs.tags;

  tagImportMap = {
    hyprland = [
      ./hyprland-config.nix
    ];
  };

  tagImports = lib.flatten (builtins.map (tag: tagImportMap.${tag}) availableTags);

in
{
  imports = [
    inputs.pete3n-mods.homeManagerModules.linux.default
  ]
  ++ builtins.attrValues homeModules
  ++ [
    ./xdg-config.nix
    ./theme-style.nix
  ]
  ++ tagImports;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  home = {
    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.05";
    username = "${makeNixAttrs.user}";
    homeDirectory = "/home/${makeNixAttrs.user}";

    packages = with pkgs; [
        xdg-user-dirs
		];
  };

	services.zoeyChar.enable = true;

  # Modules with additional program configuration
  programs = {
    home-manager.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
