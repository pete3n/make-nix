# Load user@host home configs from a directory of .nix files.
# Each file must evaluate to an attrset containing at least:
# { user, host, system, ... }.
# Pi attr files are identified by the presence of a non-null piBoard field
# and receive additional validation specific to Pi targets.
{
  lib,
  validTags,
  isLinux,
  isDarwin,
  systemOnlyTags,
  darwinOnlyTags,
  linuxOnlyTags,
  piOnlyTags,
  validPiBoards,
  validEmbeddedTargets,
  validDeployMethods,
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

      # embeddedTarget being non-null identifies an embedded system attr file.
      # The value selects which platform-specific validation block fires.
      embeddedTarget = homeAttrs.embeddedTarget or null;
      isEmbedded = embeddedTarget != null;
      isPi = embeddedTarget == "raspberry-pi";

      deployMethod = homeAttrs.deployMethod or "sd-image";

      systemTagsUsed = builtins.filter (tag: builtins.elem tag systemOnlyTags) (homeAttrs.tags or [ ]);
      darwinTagsUsed = builtins.filter (tag: builtins.elem tag darwinOnlyTags) (homeAttrs.tags or [ ]);
      linuxTagsUsed = builtins.filter (tag: builtins.elem tag linuxOnlyTags) (homeAttrs.tags or [ ]);
      piTagsUsed = builtins.filter (tag: builtins.elem tag piOnlyTags) (homeAttrs.tags or [ ]);

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

      # Pi-only tags on a non-Pi Linux is likely mistake.
      warnIfPiTagsOnNonPi =
        val:
        if isLinux system && !isPi && piTagsUsed != [ ] then
          builtins.trace "WARNING: getHomeAttrs: non-Pi Linux config ${toString homePath} uses Pi-only tags: ${lib.concatStringsSep ", " piTagsUsed}" val
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
      || throw "getHomeAttrs: invalid tags in ${toString homePath}: ${lib.concatStringsSep ", " invalidTags}\nTag must be listed in lib/default.nix to be used.";
    assert
      !isEmbedded
      || builtins.elem embeddedTarget validEmbeddedTargets
      || throw "getHomeAttrs: unknown embeddedTarget '${toString embeddedTarget}' in ${toString homePath}. Must be one of: ${lib.concatStringsSep ", " validEmbeddedTargets}";
    assert
      !isEmbedded
      || isLinux system
      || throw "getHomeAttrs: embedded config must have a Linux system target (got '${system}') in ${toString homePath}";
    assert
      !isPi
      || (homeAttrs ? piBoard)
      || throw "getHomeAttrs: missing required 'piBoard' for embeddedTarget = \"raspberry-pi\" in ${toString homePath}. Must be one of: ${lib.concatStringsSep ", " validPiBoards}";
    assert
      !isPi
      || builtins.elem (homeAttrs.piBoard or null) validPiBoards
      || throw "getHomeAttrs: invalid piBoard '${
        toString (homeAttrs.piBoard or null)
      }' in ${toString homePath}. Must be one of: ${lib.concatStringsSep ", " validPiBoards}";
    assert
      !isPi
      || builtins.elem deployMethod validDeployMethods
      || throw "getHomeAttrs: invalid deployMethod '${toString deployMethod}' in ${toString homePath}. Must be one of: ${lib.concatStringsSep ", " validDeployMethods}";
    assert
      !isPi
      || deployMethod != "pxe"
      || (homeAttrs.piBoard or null) == "rpi5"
      || throw "getHomeAttrs: deployMethod = \"pxe\" is only supported for piBoard = \"rpi5\" (got '${
        toString (homeAttrs.piBoard or null)
      }') in ${toString homePath}";
    warnIfSystemTags (
      warnIfDarwinTags (
        warnIfLinuxTags (
          warnIfPiTagsOnNonPi (lib.nameValuePair "${homeAttrs.user}@${homeAttrs.host}" homeAttrs)
        )
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
