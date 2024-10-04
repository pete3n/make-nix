{ pkgs, outputs, ... }:
# Configure ollama to use either AMD ROCM or NVIDIA CUDA based on nixpkgs configuration
let
  ollama_acceleration =
    if pkgs.config.cudaSupport then
      "cuda"
    else if pkgs.config.rocmSupport then
      "rocm"
    else
      null;
  # Set ollama environment variables to support Rizen 780m based on
  # https://github.com/ollama/ollama/issues/3189n
  ollama_env =
    if ollama_acceleration == "rocm" then
      {
        HSA_OVERRIDE_GFX_VERSION = "11.0.2";
        OLLAMA_LLM_LIBRARY = "rocm_v60000";
      }
    else
      { };
in
{
  nixpkgs = {
    overlays = [ outputs.overlays.unstable-packages ];
  };

  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    acceleration = ollama_acceleration;
    environmentVariables = ollama_env;
  };
}
