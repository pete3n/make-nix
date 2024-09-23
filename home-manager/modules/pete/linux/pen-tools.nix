{
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    aircrack-ng
    AngryOxide
    bettercap
    chisel
    gpsd
    gnuradio
    hashcat
    hcxdumptool
    hcxtools
    unstable.kismet
    masscan
    proxychains
    reaverwps-t6x
    rustscan
    socat
    termshark
  ]);
}
