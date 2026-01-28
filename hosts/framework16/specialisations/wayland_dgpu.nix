# Specialisation for Framework 16 Ryzen AI 300 series with Nvidia RTX-5070 dGPU module
# See https://github.com/NixOS/nixos-hardware/tree/master/framework/16-inch/amd-ai-300-series
{
  pkgs,
  lib,
  outputs,
  ...
}:
{
  configuration = {
    system.nixos.tags = [
      "wayland"
      "dGPU"
      "nvidia"
      "RTX-5070"
    ];
    nixpkgs.config = {
      allowUnfree = true;
      cudaSupport = true;
    };

    imports = [
      outputs.nixosModules.nvidia-scripts
    ];
		
    environment.systemPackages = with pkgs; [ cudaPackages.cudatoolkit ];

    systemd.services = {
      dgpuLink = {
        description = "Create dGPU symbolic link";
        wantedBy = [ "multi-user.target" ];
        script = # sh
          ''
            #!/bin/sh
            GPU_PCI="0000:c2:00.0"

            set -- /sys/bus/pci/devices/"$GPU_PCI"/drm/card*
            card_dir=$1
            card_name="$(basename "$card_dir")"

            ln -sf "/dev/dri/$card_name" /run/dgpu
          '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
		};

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      nvidiaSettings = true;

      prime = {
        amdgpuBusId = "PCI:195@0:0:0";
        nvidiaBusId = "PCI:44@0:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
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

    # Add symlink to dGPU for Hyprland
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", KERNELS=="0000:c2:00.0", ENV{SYSTEMD_WANTS}+="dgpuLink.service", TAG+="systemd"
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
