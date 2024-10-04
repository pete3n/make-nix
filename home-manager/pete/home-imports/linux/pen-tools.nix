{ outputs, pkgs, ... }:
{
  nixpkgs = {
    overlays = [
      outputs.overlays.local-packages
      outputs.overlays.unstable-packages
    ];
  };
  home.packages = with pkgs; [
    wireshark
    aircrack-ng
    bettercap
    chisel
    gnuradio
    gpsd
    hashcat
    hcxdumptool
    hcxtools
    local.angryoxide
    masscan
    proxychains
    reaverwps-t6x
    rustscan
    socat
    termshark
    unstable.kismet
  ];
}
