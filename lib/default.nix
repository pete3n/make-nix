{ lib, ... }:
rec {
  isPlatform = system: platform: lib.strings.hasSuffix ("-" + platform) system;
  isLinux = system: isPlatform system "linux";
  isDarwin = system: isPlatform system "darwin";

  getHomeAttrs = import ./home-attrs.nix {
    inherit
      lib
      isLinux
      isDarwin
      validTags
      systemOnlyTags
      darwinOnlyTags
      linuxOnlyTags
      ;
  };
  getHomePath = import ./home-path.nix { inherit lib; };

  makeAttrsCtx = makeAttrs: {
    system = makeAttrs.system;
    user = makeAttrs.user;
    host = makeAttrs.host;
    tags = makeAttrs.tags or [ ];
    specialisations = makeAttrs.specialisations or [ ];
    isHomeAlone = makeAttrs.isHomeAlone or false;
    useHomebrew = makeAttrs.useHomebrew or false;
    useKeys = makeAttrs.useKeys or false;
    useCache = makeAttrs.useCache or false;
    sshPubKeys = makeAttrs.sshPubKeys or [ ];
  };

  hasTag = tag: tags: builtins.elem tag tags;

  # These tags are for system level user configuration.
  validUserTags = [
    "git-ssh-user"
    "power-user"
    "ssh-user"
    "sudo-user"
    "trusted-user"
    "yubi-age-user"
  ];

  # Additional tags that can only be applied to NixOS or Nix Darwin systems.
  systemOnlyTags = [
    "local-ai"
  ]
  ++ validUserTags;

  # Tags that can only be applied to Darwin systems.
  darwinOnlyTags = [
    "aerospace"
  ];

  # Tags that can only be applied to NixOS systems.
  linuxOnlyTags = [
    "cuda"
    "hyprland"
    "mpd"
  ];

  # Configuration tags that can be applied to both home and system configs.
  validConfigTags = [
    "aichat"
    "crypto"
    "gaming"
    "git"
    "laptop"
    "media-creation"
    "messaging"
    "nixvim"
    "office"
    "p22"
    "sdr"
    "yubi-ssh-import"
    "yubi-u2f"
  ];

  validTags = systemOnlyTags ++ darwinOnlyTags ++ linuxOnlyTags ++ validConfigTags;
}
