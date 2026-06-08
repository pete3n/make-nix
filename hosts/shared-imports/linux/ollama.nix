# Local AI service configuration - enabled when "local-ai" tag is present.
# CUDA acceleration and PRIME offload are applied when cudaSupport is enabled
# via the wayland_dgpu specialisation.
{ lib, pkgs, ... }:
let
  cudaSupport = pkgs.config.cudaSupport or false;
  rocmSupport = pkgs.config.rocmSupport or false;
in
{
  hardware.nvidia-container-toolkit.enable = cudaSupport;
  services.ollama = {
    enable = true;
    package =
      if cudaSupport then
        pkgs.unstable.ollama-cuda
      else if rocmSupport then
        pkgs.unstable.ollama-rocm
      else
        pkgs.unstable.ollama-cpu;
    environmentVariables = lib.mkMerge [
      {
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_MAX_LOADED_MODELS = "2";
      }
      (lib.mkIf cudaSupport {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "PRIME";
      })
    ];
  };
}
