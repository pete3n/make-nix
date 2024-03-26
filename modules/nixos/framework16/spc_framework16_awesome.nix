# AwesomeWM config for Radeon 780M
{
  config,
  lib,
  pkgs,
  ...
}: {
  AwesomeWM.configuration = {
    system.nixos.tags = ["AwesomeWM" "Radeon 780M"];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [amdvlk rocmPackages.clr.icd];
      extraPackages32 = with pkgs.pkgsi686Linux; [amdvlk];
    };

    #services.kmscon.enable = lib.mkForce false;

    services.xserver = {
      enable = true;
      videoDrivers = ["amdgpu"];
      displayManager.startx.enable = true;
    };
  };
}
