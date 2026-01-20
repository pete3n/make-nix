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

		# Remote build user configuration
		../shared-imports/remote-builder.nix

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

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services = {
		# TODO: Check out flatpaks for home-manager with nix-flatpak
		flatpak.enable = true;
		fwupd.enable = true;
		hardware.bolt.enable = true; # boltctl
    power-profiles-daemon.enable = true;
    thermald.enable = true;
  };

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
