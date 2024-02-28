# Special config for Intel graphics using the Hyprland tiliing WM/Compositor
{
  config,
  lib,
  pkgs,
  ...
}: {
  Hyprland.configuration = {
    system.nixos.tags = ["Hyprland" "Intel-UHD"];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [intel-compute-runtime intel-media-driver];
      extraPackages32 = with pkgs.pkgsi686Linux; [intel-media-driver];
    };

    # I don't fully understand why we need xserver
    # I assume because of X-Wayland
    services.xserver.videoDrivers = ["modesetting"];

    services.kmscon.enable = lib.mkForce false;
    programs.hyprland.enable = lib.mkForce true;
  };
}
