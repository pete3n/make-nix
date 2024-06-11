# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  inputs,
  config,
  pkgs,
  lib,
  nixosModules,
  systemUsers,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # This is the hardware configuration created by the installer
    # Most importantly it contains the UUIDs for your boot and root filesystems
    # Do not use anyone else's hardware-configuration.nix or you will be
    # unable to boot
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = ["ntfs"];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/b244b8b2-6d32-4af3-86a8-356f754f9a29";
    fsType = "ext4";
  };

  nix = {
    settings.experimental-features = ["nix-command" "flakes"];

    # Extra options to keep build dependencies and derivatives for offline builds.
    # This is less aggressive than the system.includeBuildDependencies = true option
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # system.includeBuildDependencies = true;
  # Uncomment to include all build depedendencies
  # WARNING: This drastically increases the size of the closure

  ### NETWORK CONFIG ###
  networking = {
    hostName = "nixos";
    useDHCP = false; # Disable automatic DHCP; manually call: dhcpcd -B interface
    nameservers = ["192.168.1.1" "1.1.1.1" "8.8.8.8"];

    # Disable all wireless by default (use wpa_supplicant manually)
    wireless.enable = false;
    networkmanager.enable = false;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };

  # Enable resolvctl for DNS changes
  services.resolved = {
    enable = true;
    dnssec = "allow-downgrade";
    dnsovertls = "true";
    domains = ["p22"];
    fallbackDns = ["1.1.1.1" "8.8.8.8"];
  };

  # Additional p22 trusted root cert
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      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
      6doSWcNpNIwG93V05nQbhQ==
      -----END CERTIFICATE-----
    ''
  ];

  # Power, thermals
  services = {
    thermald.enable = true;
    auto-cpufreq.enable = true;
    auto-cpufreq.settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  ### Fonts and Locale ###
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";
  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "JetBrainsMono"
      ];
    })
  ];

  programs.hyprland = {
    enable = true; # Required for proper Hyprland operation
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };
  # See: https://wiki.hyprland.org/Nix

  services.printing.enable = true; # Enable CUPS
  services.hardware.bolt.enable = true; # boltctl

  services.flatpak.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  # Enable Docker - note: This requires iptables
  virtualisation.docker.enable = true;

  nixpkgs.config.allowUnfree = true;

  # System wide packages
  environment.systemPackages = with pkgs; [
    # System utils
    clinfo
    hyprcursor
    vulkan-tools
    mesa-demos
  ];
}
