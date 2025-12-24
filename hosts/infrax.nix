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
        "https://cache.nixos.org"
      ];
      trusted-substituters = [
        "http://backupsvr.p22:8000"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
    })
    (lib.mkIf makeNixAttrs.useKeys {
      # Verify at: https://app.cachix.org/cache/nix-community#pull
			# Verify at: https://github.com/NixOS/nixpkgs/blob/1f949558617ebb18bbf7005c1c4dc3407d391e93/nixos/modules/services/misc/nix-daemon.nix#L806
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    })
  ];
}
