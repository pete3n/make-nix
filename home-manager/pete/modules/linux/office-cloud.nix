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
    pika-backup
    protonmail-bridge
    remmina
    standardnotes
    thunderbird
  ];
}
