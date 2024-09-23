{
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    unstable.bisq-desktop
    unstable.monero-gui
    unstable.monero-cli
  ]);
}
