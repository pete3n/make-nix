{ lib }:
{ system, user }:
let
  platform =
    if lib.strings.hasSuffix "-darwin" system then "darwin"
    else if lib.strings.hasSuffix "-linux" system then "linux"
    else throw "Unsupported system: ${system}";

  root      = ../users/homes;  # Static path so Nix can evaluate it
  home_path = root + "/${user}/${platform}/home.nix";
in
  assert (user != "") || throw "Empty user not allowed";
  assert builtins.pathExists home_path
    || throw "Home-manager module not found: ${toString home_path}";
  home_path
