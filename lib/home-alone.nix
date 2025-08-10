{
  lib,
  dir ? ../make-configs/home-alone,
}:
let
  entries = builtins.readDir dir;
  isNixFile = name: entries.${name} == "regular" && lib.strings.hasSuffix ".nix" name;
  files = builtins.filter isNixFile (builtins.attrNames entries);
in
# Return an attrset keyed as "user@host" -> config
builtins.listToAttrs (
  map (
    name:
    let
      cfg = import (dir + "/${name}") { };
    in
    lib.nameValuePair "${cfg.user}@${cfg.host}" cfg
  ) files
)
