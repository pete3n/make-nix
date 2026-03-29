{
  lib,
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
    ++ lib.optionals (hasTag "p22" makeTags) [
      ../shared-imports/linux/p22-nfs.nix # File share
      ../shared-imports/linux/p22-printers.nix # Local printer config
      ../shared-imports/cross-platform/p22-pki.nix # Trusted root cert
      ../shared-imports/cross-platform/p22-remote-builder.nix # System is a build host for remote builds
    ]
    ++ optionalImport "yubi-u2f" ../shared-imports/linux/yubikey-pam-u2f.nix
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

      # Common Linux system packages
      ../shared-imports/linux/common-packages.nix

      ./iptables-services.nix # Allow ssh on LAN

      ../shared-imports/linux/yubikey-pam-sshd.nix
      outputs.nixosModules.yubikeyUsbipRemote
    ];

  boot = {
    kernelPackages = pkgs.linuxPackages_6_18;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "ntfs" ];
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

  networking = {
    interfaces = {
      enp191s0 = {
        ipv4 = {
          addresses = [
            {
              address = "192.168.1.8";
              prefixLength = 24;
            }
          ];
          routes = [
            # Default route
            {
              address = "0.0.0.0";
              prefixLength = 0;
              via = "192.168.1.1";
            }
          ];
        };
      };
    };
    hostName = "${makeNixAttrs.host}";
    useDHCP = false; # Disable automatic DHCP; manually call: dhcpcd -B interface
    nameservers = [ ]; # Use resolved

    # Disable all wireless by default (use wpa_supplicant manually)
    wireless.enable = false;
    networkmanager.enable = false;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  services = {
    hardware.bolt.enable = true; # boltctl
    # Enable resolvctl for DNS changes
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

    openssh = {
      enable = true;
      ports = [ 22 ];
      hostKeys = [
        {
          type = "ed25519";
          path = "/etc/ssh/ssh_host_ed25519_key";
        }
      ];
      settings = {
        AcceptEnv = "USBIP_YUBIKEY";
        PubkeyAuthentication = true;
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        UseDns = true;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        PermitTunnel = "no";
      };
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # TODO: Check out flatpaks for home-manager with nix-flatpak
    flatpak.enable = true;
    fwupd.enable = true;
    power-profiles-daemon.enable = true;
    thermald.enable = true;

  }
  // lib.optionalAttrs (hasTag "yubi-age-user" makeTags) {
    pcscd.enable = true;
    udev.packages = [ pkgs.yubikey-personalization ];
    yubikeyUsbipServer.enable = true;
  };

  programs.gnupg.agent.enable = lib.mkIf (hasTag "yubi-age-user" makeTags) true;

  ### Fonts and Locale ###
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";
  #fonts.packages = with pkgs; [ (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];

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

  # Enable Docker - note: This requires iptables
  virtualisation.docker.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Framework Desktop specific packages.
  # Common Linux packages imported from ../shared-imports/linux/system-packages.nix
  environment.systemPackages = with pkgs; [
    # System utils
    amdgpu_top
    clinfo
    mesa-demos
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
