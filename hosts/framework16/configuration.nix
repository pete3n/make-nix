# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{ pkgs, build_target, ... }:
{
  imports = [
    ./hardware-configuration.nix
    # This is the hardware configuration created by the installer
    # Most importantly it contains the UUIDs for your boot and root filesystems
    # Do not use anyone other host's hardware-configuration.nix or you will be
    # unable to boot
    ./specialisations/specialisations.nix
    # These provide different boot menu options for configurations that must
    # but implemented prior to booting Linux, such as an external GPU
    ../shared-imports/iptables-services.nix
    ../shared-imports/p22-pki.nix
    ../shared-imports/p22-nfs.nix
    ../shared-imports/p22-printers.nix
    ../shared-imports/${build_target.user}-yubikey-sc.nix
    ../shared-imports/ollama-services.nix
    ../shared-imports/crypto-services.nix
    ../shared-imports/linux/linux-packages.nix
    ../shared-imports/usrp-sdr.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "ntfs" ];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/b244b8b2-6d32-4af3-86a8-356f754f9a29";
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

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      #outputs.overlays.additions
      #outputs.overlays.modifications
      #outputs.overlays.unstable-packages
    ];
  };

  # system.includeBuildDependencies = true;
  # Uncomment to include all build depedendencies
  # WARNING: This drastically increases the size of the closure

  ### NETWORK CONFIG ###
  networking = {
    hostName = "framework16";
    useDHCP = false; # Disable automatic DHCP; manually call: dhcpcd -B interface
    nameservers = [
      "192.168.1.1"
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
    dnssec = "allow-downgrade";
    dnsovertls = "true";
    domains = [ "p22" ];
    fallbackDns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
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

  # Firmware update
  services.fwupd.enable = true;

  ### Fonts and Locale ###
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";
  #fonts.packages = with pkgs; [ (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) ];

  # See: https://wiki.hyprland.org/Nix
  services.printing.enable = true; # Enable CUPS
  services.hardware.bolt.enable = true; # boltctl

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

  # TODO: Check out flatpaks for home-manager with nix-flatpak
  services.flatpak.enable = true;

  # Enable Docker - note: This requires iptables
  virtualisation.docker.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  # System wide packages
  environment.systemPackages = with pkgs; [
    # System utils
    clinfo
    hyprcursor
    vulkan-tools
    mesa-demos
    amdgpu_top
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
