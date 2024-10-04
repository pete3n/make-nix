{ pkgs, outputs, ... }:
{
  nixpkgs = {
    overlays = [ outputs.overlays.mod-packages ];
  };
  home.packages = with pkgs; [
    heroic
    mod._86Box
  ];
}
