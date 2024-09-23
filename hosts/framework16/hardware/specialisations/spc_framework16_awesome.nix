# AwesomeWM config for Radeon 780M
{
  lib,
  pkgs,
  ...
}: {
  AwesomeWM.configuration = {
    system.nixos.tags = ["AwesomeWM" "Radeon780M"];

    imports = [
      ../../../shared-modules/X11-tools.nix
      ../../../shared-modules/nvidia-scripts.nix
    ];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
      ];
    };

    services.kmscon.enable = lib.mkForce false;

    services.xserver = {
      enable = true;
      videoDrivers = ["modesetting"];
      displayManager.startx.enable = true;
    };
  };
}
