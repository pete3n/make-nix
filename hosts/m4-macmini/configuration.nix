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
      ../shared-imports/darwin/common-packages.nix
      ./system.nix
    ];

  system.primaryUser = makeNixAttrs.user;

  networking.hostName = "${makeNixAttrs.host}";
  networking.computerName = "${makeNixAttrs.host}";
  system.defaults.smb.NetBIOSName = "${makeNixAttrs.host}";

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = false;

  nix.settings = {
    # enable flakes globally
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Auto upgrade nix package and the daemon service.
  nix.package = pkgs.nix;

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs = {
    zsh = {
      enable = true;
      enableCompletion = false; # Disabled because
      # Otherwise it breaks home-manager zsh completions
      # https://discourse.nixos.org/t/zsh-compinit-warning-on-every-shell-session/22735/4
    };
  };

  environment = {
    shells = with pkgs; [
      bash
      zsh
    ];
  };

  time.timeZone = "America/New_York";

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
}
