# Using the Hyprland tiliing WM/Compositor
{ lib, pkgs, ... }:
{
  Hyprland.configuration = {
    display_server = "wayland";
    system.nixos.tags = [
      "Hyprland"
      "Radeon780M"
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
