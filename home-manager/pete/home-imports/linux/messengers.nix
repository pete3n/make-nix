{ outputs, pkgs, ... }:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.mod-packages
    ];
  };

  home.packages =
    (with pkgs.unstable; [
      element-desktop
      skypeforlinux
      teams-for-linux
    ])
    ++ [ pkgs.mod.no-gpu-signal-desktop ];
}
