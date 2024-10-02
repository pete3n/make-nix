# Special config for external Aorus RTX 3080 GPU
{
  config,
  pkgs,
  ...
}: {
  AwesomeWM_egpu.configuration = {
    system.nixos.tags = ["AwesomeWM" "Aorus-eGPU" "RTX-3080"];

    imports = [
      ../../../shared-imports/X11-tools.nix
      ../../../shared-imports/nvidia-scripts.nix
    ];

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "555.58.02";
        sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
        sha256_aarch64 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        openSha256 = "sha256-8hyRiGB+m2hL3c9MDA/Pon+Xl6E788MZ50WrrAGUVuY=";
        settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
        persistencedSha256 = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
      };
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
        nvidiaBusId = "PCI:65:0:0";
        intelBusId = "PCI:2:0:0";
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

    services.kmscon.enable = false;

    services.xserver = {
      enable = true;
      xkb.layout = "us";
      videoDrivers = ["nvidia"];

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
  };
}
