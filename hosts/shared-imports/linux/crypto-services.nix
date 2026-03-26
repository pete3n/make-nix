{
  config,
  lib,
  makeNixAttrs,
  ...
}:
{
  age.secrets.bitcoind-rpc-hmac = {
    file = ../${makeNixAttrs.host}/secrets/bitcoind-rpc-hmac.age;
    owner = "bitcoind-main";
  };

  services.bitcoind."main" = {
    enable = true;
    dataDir = "/data/bitcoind";
    prune = 102400;
    extraConfig = ''
      			includeconf=${config.age.secrets.bitcoind-rpc-hmac.path}
      		'';
  };

  services.monero = {
    enable = true;
    dataDir = "/data/monero";
    prune = true;
    mining.enable = false;
    extraConfig = ''
      prune-blockchain-size=102400
    '';
  };
  # Disable autostart
  systemd.services.monero.wantedBy = lib.mkForce [ ];
  systemd.services.bitcoind-main.wantedBy = lib.mkForce [ ];
}
