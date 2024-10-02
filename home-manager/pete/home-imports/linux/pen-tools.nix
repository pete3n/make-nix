{
  outputs,
  pkgs,
  ...
}: {
  nixpkgs = {
    overlays = [
      outputs.overlays.local-packages
      outputs.overlays.unstable-packages
    ];
  };
  home.packages = with pkgs; [
    aircrack-ng
    local.angryoxide
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
  ];
}
