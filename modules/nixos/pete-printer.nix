{
  pkgs,
  lib,
  ...
}: {
  # Allow unfree
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "samsung-UnifiedLinuxDriver"
  #         ];

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    samsung-unified-linux-driver
  ];
}
