# Resolve correct home module path given a base path, system, and user.
# ./<base>/<user>/<platform>/home.nix
{ lib }:
{
  basePath,
  system,
  user,
}:
assert builtins.pathExists basePath || throw "getHomePath: base filepath not found: ${toString basePath}";
assert (system != "") || throw "getHomePath: system was not passed.";
assert (user != "") || throw "getHomePath: user was not passed.";

let
  platform =
    if lib.strings.hasSuffix "-darwin" system then
      "darwin"
    else if lib.strings.hasSuffix "-linux" system then
      "linux"
    else
      throw "getHomePath: unsupported system '${system}'";
  homePath = basePath + "/${user}/${platform}/home.nix";
in
assert
  builtins.pathExists homePath || throw "Home-manager module not found: ${toString homePath}";
homePath
