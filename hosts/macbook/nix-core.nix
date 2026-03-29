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
  optionalImport = tag: path: lib.optional (hasTag tag makeTags) path;
in
{
  imports =
    lib.optionals (hasTag "p22" makeTags) [
      ../shared-imports/darwin/p22-nfs.nix # File share
      ../shared-imports/cross-platform/p22-build-client.nix # Remote client builds
      ../shared-imports/cross-platform/p22-pki.nix # Trusted root cert
    ]
    ++ optionalImport "yubi-u2f" ../shared-imports/darwin/yubikey-pam-u2f.nix
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
  };

  nixpkgs.hostPlatform = "x86_64-darwin";

  age.secrets = lib.optionalAttrs (makeNixLib.hasTag "p22" makeNixAttrs.tags) {
    p22-build-key = {
      file = ./secrets/p22-build-key.age;
      path = "/etc/nix/p22-build-key";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;
}
