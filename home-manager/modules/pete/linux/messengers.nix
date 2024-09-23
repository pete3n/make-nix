{
  lib,
  pkgs,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    unstable.element-desktop
    unstable.signal-desktop
    unstable.skypeforlinux
    #unstable.teams-for-linux Electron 29.4.6 EOL marked as insecure
  ]);
}
