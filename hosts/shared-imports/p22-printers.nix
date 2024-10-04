{ pkgs, ... }:
{
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [ samsung-unified-linux-driver ];
}
