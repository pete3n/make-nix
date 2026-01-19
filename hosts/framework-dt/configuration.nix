{
  pkgs,
  outputs,
  ...
}:
{
  imports = [
    # This is the hardware configuration created by the installer
    # Most importantly it contains the UUIDs for your boot and root filesystems
    # Do not use anyone other host's hardware-configuration.nix or you will be
    # unable to boot
    ./hardware-configuration.nix

    # These provide different boot menu options for configurations that must
    # but implemented prior to booting Linux, such as an external GPU
    ./specialisations.nix

    # Infrastructure configuration for caching build systems.
    ../infrax.nix

    ./iptables-services.nix # Override NixOS firewall rules
    # and use custom iptables based ruleset

    ../shared-imports/p22-pki.nix
    ../shared-imports/p22-nfs.nix
    ../shared-imports/p22-printers.nix

    # Ensure u2f keys are present in ~/.config/Yubico/u2f_keys before enabling
    ../shared-imports/pam-u2f-common.nix
    ../shared-imports/pam-sshd.nix
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

  users = {
    groups.nixbuilders = { };
    # User for remote build processes
    users.nixbuilder = {
      group = "nixbuilders";
      isNormalUser = true;
      createHome = true;
      home = "/home/nixbuilder";
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = [
        # Primary Yubikey
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEFU2BKDdywiMqeD7LY8lgKeBo0mjHEyP7ej+Y2JNuJDAAAABHNzaDo= pete@framework16"
        # Backup Yubikey
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHwNQ411TYRwGAGINX4i4FI7Ek7lfTQv0s8vbXmnqVh/AAAABHNzaDo= pete@framework16"
      ];
    };
  };

  nix = {
    settings = {
      # Required to give access to Nix for remote builds
      trusted-users = [ "nixbuilder" ];
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
    interfaces = {
      enp191s0.ipv4.addresses = [
        {
          address = "192.168.1.8";
          prefixLength = 24;
        }
      ];
    };
    hostName = "framework-dt";
    useDHCP = false; # Disable automatic DHCP; manually call: dhcpcd -B interface
    nameservers = [ ]; # Use resolved

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

  # SSH
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
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

  # Power, thermals
  services = {
    thermald.enable = true;
    power-profiles-daemon.enable = true;
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
