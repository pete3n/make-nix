# Load Pi host configs from a directory of .nix files.
# Each file must evaluate to an attrset containing at least:
# { user, host, system, piBoard, ... }
# This is the Pi-specific counterpart to home-attrs.nix.
# Validation is stricter: piBoard and deployMethod are required and checked.
{
  lib,
  isLinux,
  validTags,
  systemOnlyTags,
  linuxOnlyTags,
  piOnlyTags,
  validPiBoards,
  validDeployMethods,
  ...
}:
{ dir }:
assert builtins.pathExists dir || throw "getPiAttrs: directory not found: ${toString dir}";
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
    builtins.sort (a: b: a < b) (builtins.attrNames entries)
  );

  loadAttrFile =
    name:
    let
      piPath = dir + "/${name}";
      piAttrs = import piPath { };

      system = piAttrs.system or "";
      piBoard = piAttrs.piBoard or null;
      deployMethod = piAttrs.deployMethod or "sd-image";

      invalidTags = builtins.filter (tag: !builtins.elem tag validTags) (piAttrs.tags or [ ]);

      # Pi configs are always Linux — warn if someone uses Darwin-only tags.
      # (No darwinOnlyTags import needed; any tag not in validTags is caught above.)
      systemTagsUsed = builtins.filter (tag: builtins.elem tag systemOnlyTags) (piAttrs.tags or [ ]);
      linuxTagsUsed  = builtins.filter (tag: builtins.elem tag linuxOnlyTags)  (piAttrs.tags or [ ]);
      piTagsUsed     = builtins.filter (tag: builtins.elem tag piOnlyTags)     (piAttrs.tags or [ ]);

      # piOnlyTags are a subset of what is valid on Pi, but not valid on other
      # Linux hosts. We don't warn here because they ARE valid — just note them
      # for awareness. If this file were ever loaded by the non-Pi path that
      # warning would fire from home-attrs.nix's linuxOnlyTags check.

      warnIfSystemTags =
        val:
        if (piAttrs.isHomeAlone or false) && systemTagsUsed != [ ] then
          builtins.trace
            "WARNING: getPiAttrs: Pi config ${toString piPath} uses system-only tags: ${lib.concatStringsSep ", " systemTagsUsed}"
            val
        else
          val;

    in
    # ── Required field assertions ────────────────────────────────────────────
    assert
      lib.isAttrs piAttrs
        || throw "getPiAttrs: file does not evaluate to attrset: ${toString piPath}";
    assert
      (piAttrs ? user)   || throw "getPiAttrs: missing 'user' in ${toString piPath}";
    assert
      (piAttrs ? host)   || throw "getPiAttrs: missing 'host' in ${toString piPath}";
    assert
      (piAttrs ? system) || throw "getPiAttrs: missing 'system' in ${toString piPath}";
    # system must be a Linux target — Pi only runs Linux
    assert
      isLinux system
        || throw "getPiAttrs: 'system' must be a Linux target (got '${system}') in ${toString piPath}";
    # piBoard is mandatory in Pi attr files
    assert
      (piAttrs ? piBoard)
        || throw "getPiAttrs: missing required 'piBoard' in ${toString piPath}. Must be one of: ${lib.concatStringsSep ", " validPiBoards}";
    assert
      builtins.elem piBoard validPiBoards
        || throw "getPiAttrs: invalid 'piBoard' value '${toString piBoard}' in ${toString piPath}. Must be one of: ${lib.concatStringsSep ", " validPiBoards}";
    # deployMethod must be a known value
    assert
      builtins.elem deployMethod validDeployMethods
        || throw "getPiAttrs: invalid 'deployMethod' value '${toString deployMethod}' in ${toString piPath}. Must be one of: ${lib.concatStringsSep ", " validDeployMethods}";
    # PXE is only valid on rpi5
    assert
      (deployMethod != "pxe" || piBoard == "rpi5")
        || throw "getPiAttrs: 'deployMethod = \"pxe\"' is only supported for piBoard = \"rpi5\" (got '${toString piBoard}') in ${toString piPath}";
    # ── Tag assertions ───────────────────────────────────────────────────────
    assert
      invalidTags == [ ]
        || throw "getPiAttrs: invalid tags in ${toString piPath}: ${lib.concatStringsSep ", " invalidTags}\n\tTag must be listed in lib/default.nix to be used.";
    # ── Warnings then result ─────────────────────────────────────────────────
    warnIfSystemTags (
      lib.nameValuePair "${piAttrs.user}@${piAttrs.host}" piAttrs
    );

in
let
  pairs = builtins.map loadAttrFile attrFiles;
in
assert (
  lib.asserts.assertMsg
    (lib.lists.length (lib.attrsets.attrNames (builtins.listToAttrs pairs))
      == lib.lists.length pairs)
    "getPiAttrs: duplicate user@host keys detected in ${toString dir}"
);
builtins.listToAttrs pairs
