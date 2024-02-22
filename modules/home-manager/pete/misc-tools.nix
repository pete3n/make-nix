{
  lib,
  pkgs,
  ...
}: {
  programs.btop = {
    enabled = true;
    settings = {
      vim_keys = true;
    };
  };
}
