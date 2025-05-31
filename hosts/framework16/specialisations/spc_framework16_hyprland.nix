# Using the Hyprland tiliing WM/Compositor
{ lib, pkgs, ... }:
{
  Hyprland.configuration = {
    display_server = "wayland";
    system.nixos.tags = [
      "Hyprland"
      "Radeon780M"
    ];

    hardware = {
			graphics = {
			enable32Bit = true; # 32-bit support for Wine Win32
      extraPackages = with pkgs;
			badoption
        [
					amdvlk
          vulkan-loader
          vulkan-validation-layers
          vulkan-extension-layer
        ];
			# 32-bit support for Wine Win32
			extraPackages32 = with pkgs.pkgsi686Linux; [
					driversi686Linux.amdvlk
          vulkan-loader
          vulkan-icd-loader
					vulkan-tools
        ];
			};
			# Enable OpenGL
			opengl = {
				enable = true;
				driSupport = true;
				driSupport32Bit = true;
			};
		};

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
  };
}
