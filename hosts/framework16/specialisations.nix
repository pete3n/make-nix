{
  config,
  lib,
  pkgs,
  outputs,
  build_target,
  ...
}:
{
  specialisation =
    let
      selectSpecialisation =
        if build_target.display_server == "x11" && build_target.egpu == false then
          "x11"
        else if build_target.display_server == "x11" && build_target.egpu == true then
          "x11_egpu"
        else if build_target.display_server == "wayland" && build_target.egpu == false then
          "wayland"
        else if build_target.display_server == "wayland" && build_target.egpu == true then
          "wayland_egpu"
        else
          null;
    in
    # Conditionally configure specialisation based on build_target parameters
    lib.optionalAttrs (selectSpecialisation != null) {
      "${selectSpecialisation}".configuration =
        if selectSpecialisation == "x11" then
          {
            system.nixos.tags = [
              "x11"
              "amd"
              "iGPU"
            ];

            system.activationScripts.setDisplayServer = {
              text = ''
                echo "x11" > /run/display_server
              '';
            };

            imports = builtins.attrValues outputs.nixosModules ++ [ ../shared-imports/linux/X11-tools.nix ];

            hardware.graphics = {
              enable = true;
              extraPackages = with pkgs; [
                vulkan-loader
                vulkan-validation-layers
                vulkan-extension-layer
              ];
            };

            services.xserver = {
              enable = true;
              videoDrivers = [ "modesetting" ];
              displayManager.startx.enable = true;
            };
          }
        else if selectSpecialisation == "x11_egpu" then
          {
            system.nixos.tags = [
              "x11"
              "eGPU"
              "nvidia"
              "RTX-3080"
            ];

            imports = builtins.attrValues outputs.nixosModules ++ [ ../shared-imports/linux/X11-tools.nix ];

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
          }
        else if selectSpecialisation == "wayland" then
          {
            system.nixos.tags = [
              "wayland"
              "amd"
              "iGPU"
            ];

            # Enable OpenGL
            hardware.graphics = {
              enable = true;
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
          }
        else if selectSpecialisation == "wayland_egpu" then
          {
            system.nixos.tags = [
              "wayland"
              "eGPU"
              "nvidia"
              "RTX-3080"
            ];
            nixpkgs.config = {
              allowUnfree = true;
              cudaSupport = true;
            };

            imports = builtins.attrValues outputs.nixosModules;

            environment.systemPackages = with pkgs; [ cudaPackages.cudatoolkit ];

            systemd.services.egpuLink = {
              description = "Create eGPU symbolic link";
              wantedBy = [ "multi-user.target" ];
              script = ''
                #!/bin/sh
                ln -sf /dev/dri/card1 /var/run/egpu
              '';
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };

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
                # NOTE: This is imperative and dependent on the USB Thunderbolt port
                # that the eGPU is connected to
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

            # Add symlink to eGPU for Hyprland
            services.udev.extraRules = ''
              ACTION=="add", SUBSYSTEM=="pci", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x2216", ENV{SYSTEMD_WANTS}+="egpu-link.service", TAG+="systemd"
            '';

            services.xserver.videoDrivers = [
              "modesetting"
              "nvidia"
            ];

            services.kmscon.enable = lib.mkForce false;
            programs.hyprland.enable = lib.mkForce true;
            programs.nvidia-scripts = {
              nvrun.enable = true;
              hypr-nvidia.enable = true;
            };
          }
        else
          null;
    };
}
