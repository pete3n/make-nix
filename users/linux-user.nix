# System-level user configuration.
# You can write this as a single file that evaluates or
# As multiple files explicitly referenced.
{
  lib,
  makeNixAttrs,
  makeNixLib,
  ...
}:
let
  userTags = makeNixLib.validUserTags;
  availableTags = builtins.filter (tag: builtins.elem tag userTags) makeNixAttrs.tags;

  tagGroupMap = {
    git-ssh-user = [
      "users"
    ];
    power-user = [
      "adbusers"
      "cdrom"
      "docker"
      "networkmanager"
      "users"
      "wheel"
    ];
    ssh-user = [ "users" ];
    sudo-user = [
      "cdrom"
      "docker"
      "users"
      "wheel"
    ];
    trusted-user = [ "users" ];
    yubi-age-user = [ "users" ];
  };

  tagDescriptionMap = {
    git-ssh-user = "User with git configuration and git ssh key";
    power-user = "Trusted user and sudoer with netman, docker, and adbuser membership.";
    trusted-user = "Add user to nix trusted users.";
    ssh-user = "User is authorized SSH access with the assigned ssh keys.";
    sudo-user = "User with sudo (wheel) access.";
    yubi-age-user = "User that uses a hardware Yubikey to manage age secrets.";
  };

  tagRoleGroups = lib.unique (lib.flatten (builtins.map (tag: tagGroupMap.${tag}) availableTags));
  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );

  hasTag = tag: builtins.elem tag availableTags;
in
{
  imports =
    lib.optionals (hasTag "yubi-age-user") [
      ./${makeNixAttrs.user}/secrets/yubi-age.nix
    ]
    ++ lib.optionals (hasTag "git-ssh-user") [
      ./${makeNixAttrs.user}/secrets/git-ssh.nix
    ];

  users.users.${makeNixAttrs.user} = {
    isNormalUser = true;
    description = tagRoleDescription;
    extraGroups = tagRoleGroups;
    openssh.authorizedKeys.keys = lib.optionals (hasTag "ssh-user") (makeNixAttrs.sshPubKeys or [ ]);
  };

  nix.settings.trusted-users = lib.mkIf (hasTag "trusted-user" || hasTag "power-user") (
    lib.mkAfter [ makeNixAttrs.user ]
  );
}
