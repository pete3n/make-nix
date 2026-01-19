# System-level user configuration.
# You can write this as a single file that evaluates or
# As multiple files explicitly referenced.
{ lib, makeNixAttrs, ... }:
let
  userRoleTags = [
    "sudoer"
    "poweruser"
    "sshuser"
  ];

  availableTags = builtins.filter (tag: builtins.elem tag userRoleTags) makeNixAttrs.tags;

  tagGroupMap = {
    sudoer = [
      "wheel"
    ];

    sshuser = [ "users" ];

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
    sshuser = "Assign ssh keys.";
  };

  userSshKeys = [
    # Primary Yubikey
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEFU2BKDdywiMqeD7LY8lgKeBo0mjHEyP7ej+Y2JNuJDAAAABHNzaDo= pete@framework16"
    # Backup Yubikey
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHwNQ411TYRwGAGINX4i4FI7Ek7lfTQv0s8vbXmnqVh/AAAABHNzaDo= pete@framework16"
  ];

  tagRoleGroups = lib.flatten (builtins.map (tag: tagGroupMap.${tag}) availableTags);
  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );

  hasTag = t: builtins.elem t availableTags;
in
{
  users.users.${makeNixAttrs.user} = {
    isNormalUser = true;
    description = tagRoleDescription;
    extraGroups = tagRoleGroups;
    openssh.authorizedKeys.keys = lib.optionals (hasTag "sshuser") userSshKeys;
  };
}
