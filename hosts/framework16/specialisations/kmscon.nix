{
  pkgs,
  lib,
  ...
}:
{
  configuration = {
    system.nixos.tags = [
      "kmscon"
      "iGPU"
    ];

    programs.hyprland.enable = lib.mkForce false;
    services.xserver.enable = lib.mkForce false;
    services.displayManager.enable = lib.mkForce false;

    services.kmscon = {
      enable = true;
      hwRender = true;
      fonts = [
        {
          name = "JetBrainsMono Nerd Font Mono";
          package = pkgs.nerd-fonts.jetbrains-mono;
        }
      ];
      extraConfig = ''
        font-size=16
        term=xterm-256color
      '';
    };

    hardware.nvidia = {
      modesetting.enable = lib.mkForce false;
      powerManagement.enable = lib.mkForce false;
      prime = {
        offload = {
          enable = lib.mkForce false;
          enableOffloadCmd = lib.mkForce false;
        };
      };
    };

    boot.kernelParams = [
      "amdgpu.modeset=1"
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        mesa
        rocmPackages.clr.icd
      ];
    };

    # Set a clean fallback console
    console = {
      earlySetup = true;
      font = "ter-v24n";
      packages = [ pkgs.terminus_font ];
    };
  };
}
