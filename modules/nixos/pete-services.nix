{pkgs, ...}: {
  services.monero = {
    enable = true;
    mining.enable = false;
  };
}
