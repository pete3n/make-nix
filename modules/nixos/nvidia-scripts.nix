# Nvidia helper shell scripts
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.nvidia-scripts;

  # Launch an application with Nvidia GPU offloading
  nvidiaRunScript =
    pkgs.writeShellScriptBin "nvrun"
      # bash
      ''
        CARD_NUMBER={$1:-0} # Use the first argument if provided, otherwise default to 0
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G$CARD_NUMBER
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export LIBVA_DRIVER_NAME=nvidia
        exec -a "$0" "$@"
      '';

  # Launch Hyprland with recommended Nvidia settings from
  # https://wiki.hyprland.org/Nvidia/
  nvidiaLaunchHypr =
    pkgs.writeShellScriptBin "Hypr-nvidia"
      # bash
      ''
        export LIBVA_DRIVER_NAME=nvidia
        export XDG_SESSION_TYPE=wayland
        export GBM_BACKEND=nvidia-drm
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export WLR_NO_HARDWARE_CURSORS=1
        exec Hyprland
      '';
in
{
  options.programs.nvidia-scripts = {
    nvrun.enable = lib.mkEnableOption "nvidia program runner";
    hypr-nvidia.enable = lib.mkEnableOption "nvidia Hyprland runner";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.nvrun.enable { environment.systemPackages = [ nvidiaRunScript ]; })
    (lib.mkIf (cfg.nvrun.enable && cfg.hypr-nvidia.enable) {
      environment.systemPackages = [ nvidiaLaunchHypr ];
    })
  ];
}
