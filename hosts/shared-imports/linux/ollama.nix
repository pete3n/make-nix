# Local AI service configuration - enabled when "local-ai" tag is present.
# CUDA acceleration and PRIME offload are applied when cudaSupport is enabled
# via the wayland_dgpu specialisation.
#
# Dual-instance architecture (cudaSupport = true):
#   Port 11434 - CUDA instance on NVIDIA dGPU
#   Port 11435 - Vulkan instance on AMD iGPU
#
# Both instances share a common model store on secondary storage to avoid
# duplicating multi-GB GGUF blobs. Runtime state (history, tmp) is separate.
{
  lib,
  config,
  pkgs,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  cudaSupport = pkgs.config.cudaSupport or false;
  rocmSupport = pkgs.config.rocmSupport or false;
  arch = pkgs.stdenv.hostPlatform.uname.processor;
  radeonIcd = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.${arch}.json";

  defaultModelPath = "/var/lib/ollama";
  modelPath = config.local-ai.modelPath;

  ollamaPriSocket = "127.0.0.1:11434";
  ollamaVulkanSocket = "127.0.0.1:11435";

  # True when models live outside the default state dir, i.e. on a separate
  # mount that the services must wait for and whose dir we must create.
  modelsRelocated = modelPath != defaultModelPath;

  shell = if makeNixLib.isLinux makeNixAttrs.system then "bash" else "zsh";
in
{
  options.local-ai.modelPath = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/ollama";
    example = "/mnt/data/ollama/models";
    description = ''
      Directory for the shared Ollama model store, read by both the CUDA
      and Vulkan instances. Override per-host to relocate large GGUF blobs
      onto secondary storage. A plain string (not a path literal) so the
      directory is treated as a runtime path rather than copied to the store.
    '';
  };

  config = {
    hardware.nvidia-container-toolkit.enable = cudaSupport;

    # Override virtualisation settings for Nvidia CUDA container support
    virtualisation.docker = lib.mkIf cudaSupport {
      enable = true;
      rootless = {
        enable = false;
        setSocketVariable = false;
      };
    };
    users.users.${makeNixAttrs.user}.extraGroups = lib.optionals cudaSupport [ "docker" ];

    services.open-webui = {
      enable = true;
      # Point Open WebUI at both backends.
      environment = lib.mkIf cudaSupport {
        OLLAMA_BASE_URLS = "http://${ollamaPriSocket},http://${ollamaVulkanSocket}";
      };
    };

    services.ollama = {
      enable = true;
      models = modelPath;

      # Static user/group so the Vulkan instance can share the model store.
      # DynamicUser (default) assigns ephemeral UIDs that prevent this.
      user = "ollama";
      group = "ollama";

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
          OLLAMA_MAX_LOADED_MODELS = "1";
          OLLAMA_FLASH_ATTENTION = "1";
        }
        (lib.mkIf cudaSupport {
          # Pin to NVIDIA dGPU only; hide iGPU from this instance
          CUDA_VISIBLE_DEVICES = "0";
          GGML_VK_VISIBLE_DEVICES = "-1";

          # PRIME offload
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "PRIME";
        })
      ];
    };

    # When relocated, ensure the model dir exists with ollama ownership.
    # systemd-tmpfiles creates leading directories as needed.
    systemd.tmpfiles.rules = lib.optionals modelsRelocated [
      "d ${modelPath} 0750 ollama ollama - -"
    ];

    # Order the primary instance after the backing mount when relocated.
    systemd.services.ollama.unitConfig.RequiresMountsFor = lib.mkIf modelsRelocated [ modelPath ];

    # --- Vulkan instance (manual systemd service) ---
    # Only created on dual-GPU machines (cudaSupport implies both GPUs present).
    # Uses AMD iGPU via Vulkan for large-model inference with system RAM.
    systemd.services.ollama-vulkan = lib.mkIf cudaSupport {
      description = "Ollama Vulkan Instance (AMD iGPU)";
      after = [
        "network-online.target"
        "ollama.service"
      ];
      wants = [ "network-online.target" ];

      # Order after the backing mount when relocated.
      unitConfig.RequiresMountsFor = lib.mkIf modelsRelocated [ modelPath ];

      environment = {
        OLLAMA_HOST = "${ollamaVulkanSocket}";
        OLLAMA_MODELS = modelPath;
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_FLASH_ATTENTION = "1";

        # Hide NVIDIA GPU; force Vulkan on AMD iGPU
        CUDA_VISIBLE_DEVICES = "-1";
        OLLAMA_IGPU_ENABLE = "1";
        OLLAMA_VULKAN = "1";
        VK_DRIVER_FILES = radeonIcd;

        # Separate HOME from primary instance to avoid runtime state collisions.
        # Ollama stores CLI history, tmp state under $HOME/.ollama/
        HOME = "/var/lib/ollama-vulkan";
      };

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        ExecStart = "${lib.getExe pkgs.unstable.ollama-vulkan} serve";
        Restart = "on-failure";
        RestartSec = 3;

        # StateDirectory creates /var/lib/ollama-vulkan owned by ollama:ollama
        StateDirectory = "ollama-vulkan";
        WorkingDirectory = "/var/lib/ollama-vulkan";

        # Grant write access to the shared model store
        ReadWritePaths = [ modelPath ];
      };
    };

    # Disable autostart
    systemd.services.ollama.wantedBy = lib.mkForce [ ];
    systemd.services.open-webui.wantedBy = lib.mkForce [ ];

    programs.${shell}.shellAliases = {
      ollama-vk = "OLLAMA_HOST=${ollamaVulkanSocket} ollama";
    };
  };
}
