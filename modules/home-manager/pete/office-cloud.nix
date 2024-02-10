{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    cryptomator
    drawio
    nextcloud-client
    onlyoffice-bin
    protonmail-bridge
    remmina
    standardnotes
    thunderbird
  ];
}
