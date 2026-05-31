{ pkgs, ... }:
{
  home.packages = with pkgs; [
    heroic
    mod._86box
  ];

  programs = {
    lutris.enable = true;
  };
}
