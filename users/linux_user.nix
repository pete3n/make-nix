# System-level user configuration.
# You can write this as a single file that evaluates or
# As multiple files explicitly referenced.
{ lib, makeNixAttrs, ... }:
let
  userRoleTags = [
    "sudoer"
    "poweruser"
  ];

  availableTags = builtins.filter (tag: builtins.elem tag userRoleTags) makeNixAttrs.tags;

  tagGroupMap = {
    sudoer = [
      "wheel"
    ];

    poweruser = [
      "networkmanager"
      "wheel"
      "docker"
      "adbusers"
    ];
  };

  tagDescriptionMap = {
    sudoer = "User with sudo (wheel) access.";
    poweruser = "Sudoer also with netman, docker, and adbuser membership.";
  };

  tagRoleGroups = lib.flatten (builtins.map (tag: tagGroupMap.${tag}) availableTags);
  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );
in
{
  users.users.${makeNixAttrs.user} = {
    isNormalUser = true;
    description = tagRoleDescription;
    extraGroups = tagRoleGroups;
  };
}
