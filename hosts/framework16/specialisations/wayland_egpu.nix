{ pkgs, lib, outputs, ... }:
{
  configuration = {
    system.nixos.tags = [
      "wayland"
      "eGPU"
      "nvidia"
      "RTX-3080"
    ];
    nixpkgs.config = {
      allowUnfree = true;
      cudaSupport = true;
    };

    imports = [
      outputs.nixosModules.nvidia-scripts
    ];

    environment.systemPackages = with pkgs; [ cudaPackages.cudatoolkit ];

    systemd.services.egpuLink = {
      description = "Create eGPU symbolic link";
      wantedBy = [ "multi-user.target" ];
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
      modesetting.enable = true;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        allowExternalGpu = true;
        # NOTE: This is imperative and dependent on the USB Thunderbolt port
        # that the eGPU is connected to
        nvidiaBusId = "PCI:65:0:0";
				amdgpuBusId = "PCI:195@0:0:0";
      };
    };

    # Enable OpenGL
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
    };

    # Add symlink to eGPU for Hyprland
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x2216", ENV{SYSTEMD_WANTS}+="egpuLink.service", TAG+="systemd"
    '';

    services.xserver.videoDrivers = [
      "modesetting"
      "nvidia"
    ];

    services.kmscon.enable = lib.mkForce false;
    programs.hyprland.enable = lib.mkForce true;
    programs.nvidia-scripts = {
      nvrun.enable = true;
      hypr-nvidia.enable = true;
    };
  };
}
