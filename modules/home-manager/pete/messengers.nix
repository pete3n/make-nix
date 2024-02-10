{
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    unstable.element-desktop
    unstable.signal-desktop
    unstable.skypeforlinux
    unstable.teams-for-linux
  ]);
}
