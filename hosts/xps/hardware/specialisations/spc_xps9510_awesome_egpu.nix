# Special config for external Aorus RTX 3080 GPU
{
  config,
  lib,
  pkgs,
  ...
}:
{
  AwesomeWM_egpu.configuration = {
    system.nixos.tags = [
      "AwesomeWM"
      "Aorus-eGPU"
      "RTX-3080"
    ];

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
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
    };

    services.udev.extraRules = ''
      # Remove integrated RTX 3050
      ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x25a0", ATTR{remove}="1"
    '';

    services.kmscon.enable = false;

    services.xserver = {
      enable = true;
      layout = "us";
      videoDrivers = [ "nvidia" ];

      config = pkgs.lib.mkOverride 0 ''

        Section "Module"
          Load		"modesetting"
        EndSection

        Section "Device"
            Identifier     "eGPU-RTX3080"
            Driver         "nvidia"
            VendorName     "NVIDIA Corporation"
            BoardName      "NVIDIA GeForce RTX 3080"
            BusID          "PCI:63:0:0"
            Option	   "AllowExternalGpus" "True"
            Option	   "AllowEmptyInitialConfiguration"
        EndSection
      '';

      displayManager = {
        startx.enable = true;
      };
    };
  };
}
