{ lib, pkgs, ... }:
{
	# Default to modesetting if drivers fail to populate
  services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];
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
