{
  lib,
  pkgs,
  makeNixAttrs,
  ...
}:
let
  userRoleTags = [
    "sudoer"
    "poweruser"
  ];

  availableTags = builtins.filter (tag: builtins.elem tag userRoleTags) makeNixAttrs.tags;

  tagDescriptionMap = {
    sudoer = "Has additional rights when connecting to the Nix daemon.";
    poweruser = "Has additional rights when connecting to the Nix daemon.";
  };

  # Add user to trusted-users if they have the sudoer or poweruser tag
  trustedUsers = lib.optionals (
    builtins.elem "sudoer" makeNixAttrs.tags || builtins.elem "poweruser" makeNixAttrs.tags
  ) [ makeNixAttrs.user ];

  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );
in
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${makeNixAttrs.user} = {
    home = "/Users/${makeNixAttrs.user}";
    shell = pkgs.zsh;
    description = tagRoleDescription;
  };

  nix.settings.trusted-users = [ "@admin" ] ++ trustedUsers;
}
