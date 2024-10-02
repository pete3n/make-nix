{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    arandr
    feh
    picom
    tdrop
    xclip
    xorg.xev
    xorg.xeyes
  ];
}
