{
  pkgs,
  lib,
  ...
}: {
  home.packages = lib.mkAfter (with pkgs; [
    aircrack-ng
    angryOxide
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
