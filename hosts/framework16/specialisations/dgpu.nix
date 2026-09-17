# Specialisation for Framework 16 Ryzen AI 300 series with Nvidia RTX-5070 dGPU module
# See https://github.com/NixOS/nixos-hardware/tree/master/framework/16-inch/amd-ai-300-series
{
  pkgs,
  lib,
  ...
}:
{
  configuration = {
    system.nixos.tags = [
      "plasma"
      "dGPU"
      "nvidia"
      "cuda"
      "RTX-5070"
    ];
    nixpkgs.config = {
      allowUnfree = true;
      cudaSupport = true;
    };

    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      nvtopPackages.nvidia
    ];

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

    services.xserver.videoDrivers = [
      "modesetting"
      "nvidia"
    ];

    services.kmscon.enable = lib.mkForce false;
  };
}
