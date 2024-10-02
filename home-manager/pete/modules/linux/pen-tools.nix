{
  inputs,
  outputs,
  pkgs,
  build_target,
  ...
}: let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = build_target.system;
  };
  __ = builtins.trace "inputs.packages.AngryOxide: ${inputs.packages.AngryOxide}";
in {
  home.packages =
    (with pkgs; [
      aircrack-ng
      bettercap
      chisel
      gpsd
      gnuradio
      hashcat
      hcxdumptool
      hcxtools
      masscan
      proxychains
      reaverwps-t6x
      rustscan
      socat
      termshark
    ])
    ++ [outputs.packages.${build_target.system}.angryoxide]
    ++ [inputs.nixpkgs-unstable.legacyPackages.${build_target.system}.kismet];
}
