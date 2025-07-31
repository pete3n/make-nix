{
  lib,
  pkgs,
  make_opts,
  ...
}:
let
  userRoleTags = [
    "sudoer"
    "poweruser"
  ];

  availableTags = builtins.filter (tag: builtins.elem tag userRoleTags) make_opts.tags;

  tagDescriptionMap = {
    sudoer = "Has additional rights when connecting to the Nix daemon.";
    poweruser = "Has additional rights when connecting to the Nix daemon.";
  };

  # Add user to trusted-users if they have the sudoer or poweruser tag
  trustedUsers =
    lib.optional (builtins.elem "sudoer" make_opts.tags)
    || (builtins.elem "poweruser" make_opts.tags) make_opts.user;

  tagRoleDescription = lib.concatStringsSep "; " (
    builtins.map (tag: tagDescriptionMap.${tag}) availableTags
  );
in
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${make_opts.user} = {
    home = "/Users/${make_opts.user}";
    shell = pkgs.zsh;
    description = tagRoleDescription;
  };

  nix.settings.trusted-users = [ "@admin" ] ++ trustedUsers;
}
