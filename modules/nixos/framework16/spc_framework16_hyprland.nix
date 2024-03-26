# Special config for Intel graphics and the integrated descrete RTX 3050
# Using the Hyprland tiliing WM/Compositor
{
  config,
  lib,
  pkgs,
  ...
}: {
  Hyprland.configuration = {
    system.nixos.tags = ["Hyprland" "Radeon 780M" ];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [amdvlk rocmPackages.clr.icd];
      extraPackages32 = with pkgs.pkgsi686Linux; [amdvlk];
    };

    # I don't fully understand why we need xserver
    # I assume because of X-Wayland
    services.xserver.videoDrivers = ["amdgpu"];

    #services.kmscon.enable = lib.mkForce false; Does KMSCon work with AMD and Hyprland?
    programs.hyprland.enable = lib.mkForce true;
  };
}
