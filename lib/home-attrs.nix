# Load user@host home configs from a directory of .nix files.
# Each file must evaluate to an attrset containing at least:
# { user, host, system, ... }.
{
  lib,
  validTags,
  isLinux,
  isDarwin,
  systemOnlyTags,
  darwinOnlyTags,
  linuxOnlyTags,
  ...
}: # This implements two curried (linked) functions allowing
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
      invalidTags = builtins.filter (tag: !builtins.elem tag validTags) (homeAttrs.tags or [ ]);
      isHomeAlone = homeAttrs.isHomeAlone or false;
      system = homeAttrs.system or "";

      systemTagsUsed = builtins.filter (tag: builtins.elem tag systemOnlyTags) (homeAttrs.tags or [ ]);
      darwinTagsUsed = builtins.filter (tag: builtins.elem tag darwinOnlyTags) (homeAttrs.tags or [ ]);
      linuxTagsUsed = builtins.filter (tag: builtins.elem tag linuxOnlyTags) (homeAttrs.tags or [ ]);
      warnIfSystemTags =
        val:
        if isHomeAlone && systemTagsUsed != [ ] then
          builtins.trace "WARNING: getHomeAttrs: home-alone config ${toString homePath} uses system-only tags: ${lib.concatStringsSep ", " systemTagsUsed}" val
        else
          val;

      warnIfDarwinTags =
        val:
        if isLinux system && darwinTagsUsed != [ ] then
          builtins.trace "WARNING: getHomeAttrs: Linux config ${toString homePath} uses Darwin-only tags: ${lib.concatStringsSep ", " darwinTagsUsed}" val
        else
          val;

      warnIfLinuxTags =
        val:
        if isDarwin system && linuxTagsUsed != [ ] then
          builtins.trace "WARNING: getHomeAttrs: Darwin config ${toString homePath} uses Linux-only tags: ${lib.concatStringsSep ", " linuxTagsUsed}" val
        else
          val;
    in
    assert
      lib.isAttrs homeAttrs
      || throw "getHomeAttrs: file does not evaluate to attrset: ${toString homePath}";
    assert (homeAttrs ? user) || throw "getHomeAttrs: missing 'user' in ${toString homePath}";
    assert (homeAttrs ? host) || throw "getHomeAttrs: missing 'host' in ${toString homePath}";
    assert (homeAttrs ? system) || throw "getHomeAttrs: missing 'system' in ${toString homePath}";
    assert
      invalidTags == [ ]
      || throw "getHomeAttrs: invalid tags in ${toString homePath}: ${lib.concatStringsSep ", " invalidTags} 
		\nTag must be listed in lib/default.nix to be used.";
    warnIfSystemTags (
      warnIfDarwinTags (
        warnIfLinuxTags (lib.nameValuePair "${homeAttrs.user}@${homeAttrs.host}" homeAttrs)
      )
    );
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
