{ pkgs, make_opts, ... }:
{
  system.primaryUser = make_opts.user;
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # substituers that will be considered before the official ones(https://cache.nixos.org)
    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    builders-use-substitutes = true;

    # Disable auto-optimise-store because of this issue:
    #   https://github.com/NixOS/nix/issues/7273
    # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
    auto-optimise-store = false;
  };

  nixpkgs.hostPlatform = "x86_64-darwin";

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;
}
