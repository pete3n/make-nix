{ pkgs, ... }:
let
  # ROCm on Radeon 780M (gfx1103) requires these runtime overrides.
  # See: https://github.com/ollama/ollama/issues/3189
  rocmEnv =
    if pkgs.config.rocmSupport then
      {
        HSA_OVERRIDE_GFX_VERSION = "11.0.2";
        OLLAMA_LLM_LIBRARY = "rocm_v60000";
      }
    else
      { };
in
{
  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    # null lets the module detect rocmSupport/cudaSupport from pkgs.config,
    # matching the behavior of the previous system module.
    acceleration = null;
    environmentVariables = rocmEnv // {
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_MAX_LOADED_MODELS = "2";
    };
  };
}
