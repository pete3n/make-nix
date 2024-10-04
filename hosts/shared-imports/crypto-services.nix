{ pkgs, ... }:
{
  services.monero = {
    enable = true;
    mining.enable = false;
  };

  #Disable autostart for monero service
  systemd.services.monero.wantedBy = pkgs.lib.mkForce [ ];
}
