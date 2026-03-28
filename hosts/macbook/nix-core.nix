{
  lib,
  pkgs,
  makeNixAttrs,
  makeNixLib,
  ...
}:
let
  makeTags = makeNixAttrs.tags;
  hasTag = makeNixLib.hasTag;
in
{
  imports =
    lib.optionals (hasTag "p22" makeTags) [
      ../shared-imports/darwin/p22-nfs.nix # File share
      ../shared-imports/cross-platform/p22-build-client.nix # Remote client builds
      ../shared-imports/cross-platform/p22-pki.nix # Trusted root cert
    ]
    ++ [
      # Nix binary cache substituter config
      ../shared-imports/cross-platform/cache-config.nix
    ];

  system.primaryUser = makeNixAttrs.user;
  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Disable auto-optimise-store because of this issue:
    #   https://github.com/NixOS/nix/issues/7273
    # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
    auto-optimise-store = false;
  };

  nixpkgs.hostPlatform = "x86_64-darwin";

  age.secrets = lib.optionalAttrs (makeNixLib.hasTag "p22" makeNixAttrs.tags) {
    p22-build-key = {
      file = ./p22-build-key.age;
      path = "/etc/nix/p22-build-key";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;
}
