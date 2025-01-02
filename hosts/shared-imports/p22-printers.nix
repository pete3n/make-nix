{
  pkgs,
  outputs,
  build_target,
  ...
}:
{
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.samsung-unified-linux-driver
    #    outputs.packages.${build_target.system}.cups-brother-hll3280cdw
  ];
}
