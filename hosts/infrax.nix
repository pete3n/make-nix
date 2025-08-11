{ lib, makeNixAttrs, ... }:
{
  nix.settings = lib.mkMerge [
    (lib.mkIf makeNixAttrs.useCache {
      substituters = [
        # This is a local Nginx cache for cache.nixos and
        # nix-community.cachix.org, see https://github.com/pete3n/nix-cache.git
        # for more information.
        "http://backupsvr.p22:8000"
        "https://nix-community.cachix.org"
      ];
      trusted-substituters = [
        "http://backupsvr.p22:8000"
        "https://nix-community.cachix.org"
      ];
    })
    (lib.mkIf makeNixAttrs.useKeys {
      # Verify at: https://app.cachix.org/cache/nix-community#pull
      trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    })
  ];
}
