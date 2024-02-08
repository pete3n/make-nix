# Special config for external Aorus RTX 3080 GPU
{
  config,
  lib,
  pkgs,
  ...
}: {
  XPS-9510_egpu.configuration = {
    system.nixos.tags = ["Aorus-eGPU" "RTX-3080"];

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.production;
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
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:63:0:0";
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

    # X server config
    services.xserver.videoDrivers = ["nvidia"];
  };
}
