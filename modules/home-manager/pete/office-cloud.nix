{
  lib,
  pkgs,
  ...
}: {
  # Zathura PDF viewer with VIM motions
  programs.zathura = {
    enable = true;
  };

  home.packages = with pkgs; [
    cryptomator
    drawio
    nb
    nextcloud-client
    onlyoffice-bin
    protonmail-bridge
    remmina
    standardnotes
    thunderbird
  ];
}
