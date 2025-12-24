{ pkgs, ... }:
{
  configuration = {
    system.nixos.tags = [
      "x11"
      "amd"
      "iGPU"
    ];

    system.activationScripts.setDisplayServer = {
      text = ''
        printf "x11" > /run/display_server
      '';
    };

    imports = [ ../../shared-imports/linux/X11-tools.nix ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
      ];
    };

    services.xserver = {
      enable = true;
      videoDrivers = [ "modesetting" ];
      displayManager.startx.enable = true;
    };
  };
}
