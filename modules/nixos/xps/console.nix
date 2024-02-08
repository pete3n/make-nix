{
  pkgs,
  lib,
  ...
}: {
  #KMS console causes issues with Hyprland on the XPS
  console = {
    earlySetup = true;
    packages = with pkgs; [
      terminus_font
      powerline-fonts
      powerline-symbols
    ];
    keyMap = "us";
  };
}
