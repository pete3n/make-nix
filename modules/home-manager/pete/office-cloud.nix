{
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    onlyoffice-bin
    drawio
    nextcloud-client
    cryptomator
  ]);
}
