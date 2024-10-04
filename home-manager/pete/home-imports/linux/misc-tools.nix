{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bottles
    cdrkit
    litemdview
    xfce.thunar
  ];
}
