# AwesomeWM config for Radeon 780M
{
  config,
  lib,
  pkgs,
  ...
}: {
  AwesomeWM.configuration = {
    system.nixos.tags = ["AwesomeWM" "Radeon780M"];

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
