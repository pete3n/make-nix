# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  inputs,
  system-users,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_6_6;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  nix = {
    settings.tarball-ttl = 3600 * 24 * 365 * 10; # 10 Year ttl for offline config
    settings.experimental-features = ["nix-command" "flakes"];
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  system.includeBuildDependencies = true;

  networking.hostName = "nix-tac"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Disable network manager
  networking.networkmanager.enable = false;

  # Disable wireless by default (use wpa_supplicant manually)
  networking.wireless.enable = false;

  # Enable SSH support for provisioning
  services.sshd.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable resolvctl for DNS changes
  services.resolved = {
    enable = true;
    dnssec = "false";
    domains = ["~."];
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
  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "JetBrainsMono"
      ];
    })
  ];

  programs.hyprland.enable = true; # Required for proper Hyprland operation
  # See: https://wiki.hyprland.org/Nix

  services.printing.enable = true; # Enable CUPS
  services.hardware.bolt.enable = true; # boltctl

  # Enable Docker - note: This requires iptables
  virtualisation.docker.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-wide packages
  environment.systemPackages = with pkgs; [
    # Place special system specific tools/packages here
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
  #system.includeBuildDependencies = true;
}
