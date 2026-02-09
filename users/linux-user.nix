# System-level user configuration.
# You can write this as a single file that evaluates or
# As multiple files explicitly referenced.
{ lib, makeNixAttrs, ... }:
let
  userTags = [
    "poweruser"
    "sshuser"
    "sudoer"
    "trusteduser"
    "yubi-age-user"
  ];

  availableTags = builtins.filter (tag: builtins.elem tag userTags) makeNixAttrs.tags;

  tagGroupMap = {
    poweruser = [
      "networkmanager"
      "wheel"
      "docker"
      "adbusers"
    ];
    sshuser = [ "users" ];
    sudoer = [ "wheel" ];
    trusteduser = [ "users" ];
    yubi-age-user = [ "users" ];
  };

  tagDescriptionMap = {
    poweruser = "Trusted user and sudoer with netman, docker, and adbuser membership.";
    trusteduser = "Add user to nix trusted users.";
    sshuser = "User is authorized SSH access with the assigned ssh keys.";
    sudoer = "User with sudo (wheel) access.";
    yubi-age-user = "User that uses a hardware Yubikey to manage age secrets.";
  };

  tagRoleGroups = lib.flatten (builtins.map (tag: tagGroupMap.${tag}) availableTags);
  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );

  hasTag = tag: builtins.elem tag availableTags;
in
{
  imports = lib.optionals (hasTag "yubi-age-user") [
    ./${makeNixAttrs.user}/secrets/yubi-age.nix
  ];

  users.users.${makeNixAttrs.user} = {
    isNormalUser = true;
    description = tagRoleDescription;
    extraGroups = tagRoleGroups;
    openssh.authorizedKeys.keys = lib.optionals (hasTag "sshuser") makeNixAttrs.sshPubKeys;
  };

  nix.settings.trusted-users = lib.mkIf (hasTag "trusteduser" || hasTag "poweruser") (
    lib.mkAfter [ makeNixAttrs.user ]
  );
}
