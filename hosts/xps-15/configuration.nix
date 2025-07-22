# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  config,
  pkgs,
  lib,
  nixosModules,
  systemUsers,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    # This is the hardware configuration created by the installer
    # Most importantly it contains the UUIDs for your boot and root filesystems
    # Do not use anyone else's hardware-configuration.nix or you will be
    # unable to boot
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_6_6;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/a0f72048-c503-4002-a69e-05cba47bf75b";
    fsType = "ext4";
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

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
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

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
    dnssec = "false";
    domains = [ "~." ];
    extraConfig = ''
      DNSOverTLS=true
    '';
  };

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
  fonts.packages = with pkgs; [ (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];

  programs.hyprland.enable = true; # Required for proper Hyprland operation
  # See: https://wiki.hyprland.org/Nix

  services.printing.enable = true; # Enable CUPS
  services.hardware.bolt.enable = true; # boltctl

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

  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
  };
  # System wide packages
  environment.systemPackages = with pkgs; [
    # System utils
    cudaPackages.cudatoolkit # TODO: Test CUDA functionaliity
    mesa-demos
    vulkan-tools
  ];
}
