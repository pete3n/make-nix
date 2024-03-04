# Special config for external Aorus RTX 3080 GPU with Hyprland
{
  config,
  lib,
  pkgs,
  ...
}: {
  Hyprland_egpu.configuration = {
    system.nixos.tags = ["Hyprland" "Aorus-eGPU" "RTX-3080"];

    systemd.services.egpuFlag = {
      description = "Create eGPU flag file";
      wantedBy = ["multi-user.target"];
      script = ''
        if [[ $config.system.nixos.tags} == *'Aorus-eGPU'* ]]; then
        	mkdir -p /var/run/egpu
        	touch /var/run/egpu
        fi
      '';
    };

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.production;
      modesetting.enable = false;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        allowExternalGpu = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:63:0:0";
      };
    };

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [nvidia-vaapi-driver intel-media-driver];
      extraPackages32 = with pkgs.pkgsi686Linux; [nvidia-vaapi-driver intel-media-driver];
    };

    services.udev.extraRules = ''
      # Remove integrated RTX 3050
      ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x25a0", ATTR{remove}="1"
    '';

    services.xserver.videoDrivers = ["modesetting" "nvidia"];

    services.kmscon.enable = lib.mkForce false;
    programs.hyprland.enable = lib.mkForce true;
  };
}
