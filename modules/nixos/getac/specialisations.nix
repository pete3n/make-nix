# This module builds boot menu specialisation options for either the
# Getac's intel graphics or an external Aorus 3080 GPU
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Special profiles for the Getac are prefixed with spc_getac
  currentDirFiles = builtins.attrNames (builtins.readDir ./.);
  specializationFilenames = lib.filter (filename: lib.hasPrefix "spc_getac" filename) currentDirFiles;
  importedSpecializations = map (filename: import (./. + "/${filename}") {inherit pkgs config lib;}) specializationFilenames;
in {
  # Allow specific non-free packages here
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
    ];

  specialisation = builtins.foldl' (acc: module: acc // module) {} importedSpecializations;
}
