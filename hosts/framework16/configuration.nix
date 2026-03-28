# See NixOS hardware project: https://github.com/NixOS/nixos-hardware/tree/master/framework/16-inch
{
  lib,
  inputs,
  pkgs,
  outputs,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  makeTags = makeNixAttrs.tags;
  hasTag = makeNixLib.hasTag;
  optionalImport = tag: path: lib.optional (hasTag tag makeTags) path;
in
{
  imports =
    optionalImport "local-ai" ../shared-imports/linux/ollama.nix
    ++ optionalImport "crypto" ../shared-imports/linux/crypto-services.nix
    ++ optionalImport "sdr" ../shared-imports/linux/usrp-sdr.nix
    ++ lib.optionals (hasTag "p22" makeTags) [
      ../shared-imports/cross-platform/p22-build-client.nix # Remote client builds
      ../shared-imports/cross-platform/p22-pki.nix # Trusted root cert
      ../shared-imports/linux/p22-nfs.nix # File share
      ../shared-imports/linux/p22-printers.nix # Local printer config
    ]
    ++ [
      # This is the hardware configuration created by the installer
      # Most importantly it contains the UUIDs for your boot and root filesystems
      # Do not use anyone other host's hardware-configuration.nix or you will be
      # unable to boot
      ./hardware-configuration.nix

      # These provide different boot menu options for configurations that must
      # but implemented prior to booting Linux, such as an external GPU
      ./specialisations.nix

      # Nix binary cache substituter config
      ../shared-imports/cross-platform/cache-config.nix

      # Common Linux packages
      ../shared-imports/linux/common-packages.nix

      # Override NixOS firewall rules and use custom iptables based ruleset
      ../shared-imports/linux/iptables-services.nix

      ../shared-imports/pam-fprint-yubikey.nix
      ../shared-imports/pam-u2f-common.nix
      outputs.nixosModules.yubikeyUsbipServer # Use Yubikey on remote systems
    ]
    ++ [ inputs.pete3n-mods.nixosModules.default ]
    ++ [ inputs.pete3n-mods.nixosModules.hardware.framework16.fw16-kbd-alsd ]
    ++ [ inputs.pete3n-mods.nixosModules.hardware.framework16.fw16-disable-wake-triggers ];

  documentation = {
    man.enable = true;
    man.generateCaches = true;
  };

  boot = {
    # Workaround for suspend then sleep issues.
    # Resolved amdgpu VPE queue reset failed / ib ring test failed (-110)
    # Resolved nvme drive sleep issues.
    kernelParams = [
      "rtc_cmos.use_acpi_alarm=1"
      "amdgpu.ip_block_mask=0x7FF"
      "nvme_core.default_ps_max_latency_us=1000"
    ];

    # Removable CD-ROM support
    kernelModules = [
      "sg"
    ];

    # Kernel 6.19 build error
    # kernelPackages = pkgs.linuxPackages_latest;
    kernelPackages = pkgs.linuxPackages_6_18;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "ntfs" ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "armv7l-linux"
    ];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/b244b8b2-6d32-4af3-86a8-356f754f9a29";
    fsType = "ext4";
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # Extra options to keep build dependencies and derivatives for offline builds.
    # This is less aggressive than the system.includeBuildDependencies = true option
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.local-packages
      outputs.overlays.mod-packages
    ];
  };

  # system.includeBuildDependencies = true;
  # Uncomment to include all build depedendencies
  # WARNING: This drastically increases the size of the closure

  ### NETWORK CONFIG ###
  networking = {
    hostName = "framework16";
    useDHCP = true;
    dhcpcd.enable = true;
    nameservers = [ ]; # Use resolved

    # Disable all wireless by default (use wpa_supplicant manually)
    wireless.enable = false;
    networkmanager.enable = false;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  age.secrets = lib.optionalAttrs (makeNixLib.hasTag "p22" makeNixAttrs.tags) {
    p22-build-key = {
      file = ./p22-build-key.age;
      path = "/etc/nix/p22-build-key";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  security.pam.services = {
    login.fprintAuth = true; # Enable fingerprint sensor login
  }
  // lib.mkIf (makeNixLib.hasTag "hyprland" makeNixAttrs.tags) {
    hyprlock = { }; # Only enable hyprlock pam module if using hyprland
  };

  services = {
    # Auto control keyboard backlight. Save power in sunlight.
    fw16-kbd-alsd.enable = true;
    # Disable all suspend wake triggers except the power button.
    fw16-disable-wake-triggers.enable = true;

    # Control lid open/close events with lidmond
    logind = {
      settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };

    lidmond = {
      enable = true;
      accessGroup = "wheel";
    };

    # Allow remotely connecting Yubikey
    yubikeyUsbipServer = {
      enable = true;
    };

    resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      dnsovertls = "opportunistic";

      extraConfig = ''
        DNS=192.168.1.1
        Domains=~p22
      '';

      fallbackDns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };

    # Generate system public key
    openssh = {
      enable = true;
      hostKeys = [
        {
          type = "ed25519";
          path = "/etc/ssh/ssh_host_ed25519_key";
        }
      ];
    };

    # Power and thermal management
    thermald.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;

    # Audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Firmware update
    fwupd.enable = true;

    # See: https://wiki.hyprland.org/Nix
    hardware.bolt.enable = true; # boltctl

    # TODO: Check out flatpaks for home-manager with nix-flatpak
    flatpak.enable = true;

  };

  # Portals must be enable system wide for Flatpak support
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
      };
    };
  };

  ### Fonts and Locale ###
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";

  # Enable Docker - NOTE: This requires iptables
  virtualisation.docker.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Framework16 specific system packages.
  # Common packages imported from ../shared-imports/linux/system-packages.nix
  environment.systemPackages = with pkgs; [
    amdgpu_top
    framework-tool
    framework-tool-tui
    mesa-demos
    nvtopPackages.amd
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    vulkan-tools
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
