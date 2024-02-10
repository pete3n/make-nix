{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    arandr
    feh
    picom
    xclip
  ];
}
