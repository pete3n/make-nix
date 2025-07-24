{ pkgs, lib, ... }:
{
  configuration = {
    system.nixos.tags = [
      "wayland"
      "amd"
      "iGPU"
    ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true; # 32-bit support for Wine Win32
        extraPackages = with pkgs; [
          vulkan-loader
          vulkan-validation-layers
          vulkan-extension-layer
          vulkan-tools
        ];
      };
    };
    nixpkgs.config.rocmSupport = true;

    # I don't fully understand why we need xserver
    # I assume because of X-Wayland
    services.xserver.videoDrivers = [ "modesetting" ];
    services.kmscon.enable = lib.mkForce false;
    programs.hyprland = {
      enable = lib.mkForce true;
      package = pkgs.hyprland;
    };
  };
}
