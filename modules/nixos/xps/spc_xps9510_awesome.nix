# Special config for Intel graphics and the integrated descrete RTX 3050
{
  config,
  lib,
  pkgs,
  ...
}: {
  AwesomeWM.configuration = {
    system.nixos.tags = ["AwesomeWM" "Intel-UHD" "RTX_3050"];

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.production;
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      nvidiaSettings = true;

      prime = {
        offload.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [intel-compute-runtime nvidia-vaapi-driver intel-media-driver];
      extraPackages32 = with pkgs.pkgsi686Linux; [nvidia-vaapi-driver intel-media-driver];
    };

    services.kmscon.enable = lib.mkForce false;

    services.xserver = {
      enable = true;
      videoDrivers = ["modesetting" "nvidia"];
      displayManager.startx.enable = true;
    };
  };
}
