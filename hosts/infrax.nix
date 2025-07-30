{ build_target, ... }:
{
  nix.settings =
    if build_target.useCache then
      {
        substituters = [
          "http://backupsvr.p22:8000"
          "https://cache.nixos.org"
        ];
        trusted-substituters = [
          "http://backupsvr.p22:8000"
        ];
        extra-trusted-public-keys = [
          "backupsvr.p22-1:Ed25519_sig"
        ];
      }
    else
      { };
}
