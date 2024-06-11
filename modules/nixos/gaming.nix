{
  inputs,
  pkgs,
  lib,
  ...
}: {
  #nixpkgs.config.allowUnfreePredicate = pkg:
  #  builtins.elem (lib.getName pkg) [
  #    "steam"
  #  ];

  programs.steam.enable = true;
}
