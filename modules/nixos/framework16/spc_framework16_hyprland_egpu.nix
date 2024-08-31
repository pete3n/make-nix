# Special config for external Aorus RTX 3080 GPU with Hyprland
{
  config,
  lib,
  pkgs,
  ...
}: {
  Hyprland_egpu.configuration = {
    system.nixos.tags = ["Hyprland" "Aorus-eGPU" "RTX-3080"];
    nixpkgs.config = {
      allowUnfree = true;
      cudaSupport = true; # For eGPU config
    };

    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
    ];

    systemd.services.egpuLink = {
      description = "Create eGPU symbolic link";
      wantedBy = ["multi-user.target"];
      script = ''
        #!/bin/sh
        ln -sf /dev/dri/card1 /var/run/egpu
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "555.58.02";
        sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
        sha256_aarch64 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
        persistencedSha256 = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
      };
      modesetting.enable = false;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        allowExternalGpu = true;
        nvidiaBusId = "PCI:65:0:0";
        intelBusId = "PCI:2:0:0";
      };
    };

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [nvidia-vaapi-driver intel-media-driver];
      extraPackages32 = with pkgs.pkgsi686Linux; [nvidia-vaapi-driver intel-media-driver];
    };

    services.udev.extraRules = ''
       # Remove integrated RTX 3050
       ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x25a0", ATTR{remove}="1"
      # Add symlink to eGPU for Hyprland
      ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x2216", ENV{SYSTEMD_WANTS}+="egpu-link.service", TAG+="systemd"
    '';

    services.xserver.videoDrivers = ["modesetting" "nvidia"];

    services.kmscon.enable = lib.mkForce false;
    programs.hyprland.enable = lib.mkForce true;
  };
}
