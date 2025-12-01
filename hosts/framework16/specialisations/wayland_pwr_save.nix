{ pkgs, lib, ... }:
{
	inheritParentConfig = true;
  configuration = {
    system.nixos.tags = [
			"power_saver"
      "wayland"
      "amd"
      "iGPU"
    ];

		boot.kernelParams = [
			# Let cpufreq governors manage amd_pstate
			"amd_pstate=passive"

			# Aggressive power saving for NVMe + PCIe
			"pcie_aspm=force"
			"nvme_core.default_ps_max_latency_us=55000"
		];

		powerManagement = {
			enable = true;
			cpuFreqGovernor = "powersave";
		};

		environment.systemPackages = with pkgs; [
			linuxPackages.cpupower
			ryzenadj # Ryzen power tweaks
		];

		systemd.services.cpu-cap = {
			description = "Limit CPU freq. for battery saver mode";
			wantedBy = [ "multi-user.target" ];
			after = [ "multi-user.target" ];
			serviceConfig = {
				Type = "oneshot";
				ExecStart = ''
					${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set -u 1.6GHz -d 800MHz
				'';
			};
		};

		services.powertop.enable = true;

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true; # 32-bit support for Wine Win32
        extraPackages = with pkgs; [
          vulkan-loader
          vulkan-validation-layers
          vulkan-extension-layer
          vulkan-tools
        ];
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
