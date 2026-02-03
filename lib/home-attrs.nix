# Load user@host home configs from a directory of .nix files.
# Each file must evaluate to an attrset containing at least:
# { user, host, system, ... }.
{ lib }: # This implements two curried (linked) functions allowing
{ dir }: # lib to be bound once and dir multiple times.
assert builtins.pathExists dir || throw "getHomeAttrs: directory not found: ${toString dir}";
let

  entries = builtins.readDir dir;

  fileType =
    name:
    let
      val = entries.${name};
    in
    if builtins.isAttrs val then val.type else val;

  isNixFile =
    name:
    let
      type = fileType name;
    in
    (type == "regular" || type == "symlink") && lib.strings.hasSuffix ".nix" name;

  attrFiles = builtins.filter isNixFile (
    builtins.sort (name1: name2: name1 < name2) (builtins.attrNames entries)
  );

  loadAttrFile =
    name:
    let
      homePath = dir + "/${name}";
      homeAttrs = import homePath { };
    in
    assert
      lib.isAttrs homeAttrs
      || throw "getHomeAttrs: file does not evaluate to attrset: ${toString homePath}";
    assert (homeAttrs ? user) || throw "getHomeAttrs: missing 'user' in ${toString homePath}";
    assert (homeAttrs ? host) || throw "getHomeAttrs: missing 'host' in ${toString homePath}";
    assert (homeAttrs ? system) || throw "getHomeAttrs: missing 'system' in ${toString homePath}";
    lib.nameValuePair "${homeAttrs.user}@${homeAttrs.host}" homeAttrs;
in

let
  pairs = builtins.map loadAttrFile attrFiles;
in
assert (
  lib.asserts.assertMsg (
    lib.lists.length (lib.attrsets.attrNames (builtins.listToAttrs pairs)) == lib.lists.length pairs
  ) "getHomeAttrs: duplicate user@host keys detected in ${toString dir}"
);
builtins.listToAttrs pairs
