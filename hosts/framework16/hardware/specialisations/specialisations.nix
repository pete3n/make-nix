{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Special profiles for the Framework16 are prefixed with spc_framework16
  currentDirFiles = builtins.attrNames (builtins.readDir ./.);
  specializationFilenames = lib.filter (
    filename: lib.hasPrefix "spc_framework16" filename
  ) currentDirFiles;
  importedSpecializations = map (
    filename: import (./. + "/${filename}") { inherit pkgs config lib; }
  ) specializationFilenames;
in
{
  specialisation = builtins.foldl' (acc: module: acc // module) { } importedSpecializations;
}
