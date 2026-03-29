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
      # Import other system packages and configuration options
			#./yabai.nix
			#./skhd.nix
    ];

  system.primaryUser = makeNixAttrs.user;

  networking.hostName = "${makeNixAttrs.host}";
  networking.computerName = "${makeNixAttrs.host}";
  system.defaults.smb.NetBIOSName = "${makeNixAttrs.host}";

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = false;

  services = {
    aerospace = lib.mkIf (hasTag "aerospace" makeTags) {
      enable = true;
    };
    sketchybar = lib.mkIf (hasTag "aerospace" makeTags) {
      enable = true;
    };
  };

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
