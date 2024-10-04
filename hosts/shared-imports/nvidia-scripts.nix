# Nvidia helper shell scripts
{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    # Launch an application with Nvidia GPU offloading
    (pkgs.writeShellScriptBin "nvrun" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      export LIBVA_DRIVER_NAME=nvidia
      exec -a "$0" "$@"
    '')
    # Launch Hyprland with recommended Nvidia settings from
    # https://wiki.hyprland.org/Nvidia/
    (pkgs.writeShellScriptBin "hypr-nv" ''
      export LIBVA_DRIVER_NAME=nvidia
         export XDG_SESSION_TYPE=wayland
         export GBM_BACKEND=nvidia-drm
         export __GLX_VENDOR_LIBRARY_NAME=nvidia
         export WLR_NO_HARDWARE_CURSORS=1
         exec Hyprland
    '')
  ];
}
