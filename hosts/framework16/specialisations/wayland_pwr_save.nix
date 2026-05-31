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
      cpuFreqGovernor = "schedutil";
      cpufreq.min = 800000; # 800 MHz
      cpufreq.max = 2400000; # 2.4 GHz
      scsiLinkPolicy = "min_power";
      powertop.enable = true;

      # Deprecated
      # It will be removed in NixOS 26.11.
      #                  It is recommended to create an explicit systemd oneshot service instead,
      #                  that is pulled in at the right time during the boot process.
      #                  See https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html
      #                 for more information on possible targets that can be used for this.
      #                  If you also want to run this service upon waking up from resume, the recommended
      #                  method to do so is described here:
      #                  https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html#sleep.target
      #powerUpCommands = ''
      #  				${pkgs.brightnessctl}/bin/brightnessctl set 25%
      #  			'';
    };

    environment.systemPackages = with pkgs; [
      linuxPackages.cpupower
      ryzenadj # Ryzen power tweaks
    ];

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
