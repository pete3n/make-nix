{pkgs, ...}: {
  home.packages = with pkgs; [
    heroic
    _86Box-with-roms
  ];
}
