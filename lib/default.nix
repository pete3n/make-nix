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
      piOnlyTags
      validPiBoards
      validEmbeddedTargets
      validDeployMethods
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
    # Embedded system fields — null on standard hosts.
    # embeddedTarget selects the platform; board-specific fields sit alongside it.
    embeddedTarget = makeAttrs.embeddedTarget or null;
    piBoard = makeAttrs.piBoard or null;
    buildSystem = makeAttrs.buildSystem or null;
    deployMethod = makeAttrs.deployMethod or "sd-image";
  };

  # Map a piBoard value to the nixos-raspberrypi base module attrpath.
  # Usage: nixosModules.${makeNixLib.piBaseModAttr ctx.piBoard}.base
  piBaseModAttr =
    board:
    let
      boardMap = {
        "rpi02" = "raspberry-pi-02";
        "rpi3" = "raspberry-pi-3";
        "rpi4" = "raspberry-pi-4";
        "rpi5" = "raspberry-pi-5";
      };
    in
    boardMap.${board}
      or (throw "piBaseModAttr: unknown piBoard '${board}'. Must be one of: ${lib.concatStringsSep ", " validPiBoards}");

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
    "wayland"
    "x11"
  ];

  #TODO: Implement wayland, x11 in specialisations

  piOnlyTags = [
    "pi-usb-gadget" # USB OTG/ethernet gadget mode (Zero 2W, CM4)
    "pi-camera" # libcamera / camera module support
    "pi-gpio" # GPIO access
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

  validTags = systemOnlyTags ++ darwinOnlyTags ++ linuxOnlyTags ++ piOnlyTags ++ validConfigTags;

  # Known embedded platform identifiers. Adding a new platform here is the
  # validation dispatch in home-attrs.nix and builder dispatch
  # in flake.nix both key off this list.
  validEmbeddedTargets = [
    "raspberry-pi"
    # "riscv"   # future
  ];

  # Valid piBoard identifiers. These are the keys used in makeAttrs Pi files and
  # map directly to the nvmd nixos-raspberrypi nixosModules namespace.
  validPiBoards = [
    "rpi02" # Pi Zero 2 W
    "rpi3" # Pi 3 / 3B / 3B+
    "rpi4" # Pi 4
    "rpi5" # Pi 5
  ];

  validDeployMethods = [
    "sd-image" # Build .sdImage, dd to card — all boards
    "pxe" # PXE/network boot — rpi5 only
  ];
}
