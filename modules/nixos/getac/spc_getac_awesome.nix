# Special config for Intel graphics
{
  config,
  lib,
  pkgs,
  ...
}: {
  AwesomeWM.configuration = {
    system.nixos.tags = ["AwesomeWM" "Intel-UHD"];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [intel-compute-runtime intel-media-driver];
      extraPackages32 = with pkgs.pkgsi686Linux; [intel-compute-runtime intel-media-driver];
    };

    services.kmscon.enable = lib.mkForce false;

    services.xserver = {
      enable = true;
      videoDrivers = ["modesetting"];
      displayManager.startx.enable = true;
    };
  };
}
