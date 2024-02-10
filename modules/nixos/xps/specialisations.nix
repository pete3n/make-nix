# This module builds boot menu specialisation options for either the
# integrated descrete RTX 3050 GPU or an external Aorus 3080 GPU
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Special profiles for the XPS 9510 are prefixed with spc_xps9510
  currentDirFiles = builtins.attrNames (builtins.readDir ./.);
  specializationFilenames = lib.filter (filename: lib.hasPrefix "spc_xps9510" filename) currentDirFiles;
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
