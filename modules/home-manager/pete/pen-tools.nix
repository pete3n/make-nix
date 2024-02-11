{
  pkgs,
  lib,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    aircrack-ng
    AngryOxide
    bettercap
    chisel
    gpsd
    hashcat
    hcxdumptool
    hcxtools
    unstable.kismet
    masscan
    proxychains
    reaverwps-t6x
    rustscan
    socat
  ]);
}
