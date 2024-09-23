{pkgs, ...}:
#
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.pete = {
    home = "/Users/pete";
    shell = pkgs.zsh;
    description = "pete3n";
  };

  nix.settings.trusted-users = ["pete"];
}
