{ pkgs, outputs, ... }:
{
  configuration = {
    system.nixos.tags = [
      "x11"
      "eGPU"
      "nvidia"
      "RTX-3080"
    ];

    imports = [
      outputs.nixosModules.nvidia-scripts
      ../../shared-imports/linux/X11-tools.nix
    ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # NOTE: This is imperative and dependent on the USB Thunderbolt port
        # that the eGPU is connected to
        allowExternalGpu = true;
        nvidiaBusId = "PCI:65:0:0";
        intelBusId = "PCI:2:0:0";
      };
    };

    # Enable OpenGL
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        nvidia-vaapi-driver
        intel-media-driver
      ];
    };

    services.xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = [ "nvidia" ];

      # NOTE: This is imperative and dependent on the USB Thunderbolt port
      # that the eGPU is connected to
      config = pkgs.lib.mkOverride 0 ''

        Section "Module"
        	Load		"modesetting"
        EndSection

        Section "Device"
        		Identifier     "eGPU-RTX3080"
        		Driver         "nvidia"
        		VendorName     "NVIDIA Corporation"
        		BoardName      "NVIDIA GeForce RTX 3080"
        		BusID          "PCI:65:0:0"
        		Option	   "AllowExternalGpus" "True"
        		Option	   "AllowEmptyInitialConfiguration"
        EndSection
      '';

      displayManager = {
        startx.enable = true;
      };
    };

    programs.nvidia-scripts.nvrun.enable = true;
  };
}
