# local AI service configuration - enabled when "local-ai" tag is present.
# CUDA acceleration and PRIME offload are applied when cudaSupport is enabled
# via the wayland_dgpu / wayland_egpu specialisations.
#
# Dual-instance architecture (cudaSupport = true):
#   Port 11434 - CUDA instance on NVIDIA dGPU/eGPU
#   Port 11435 - Vulkan instance on AMD iGPU
#
# Both instances share a common model store (local-ai.modelPath) to avoid
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

  # Shared model store, independent of either service's StateDirectory.
  # Override per-host via local-ai.modelPath for secondary storage.
  defaultModelPath = "/var/lib/ollama-shared/models";
  modelPath = config.local-ai.modelPath;

  ollamaPriSocket = "127.0.0.1:11434";
  ollamaVulkanSocket = "127.0.0.1:11435";

  # True when models live outside the default path, i.e. on a separate
  # mount that the services must wait for.
  modelsRelocated = modelPath != defaultModelPath;

  shell = if makeNixLib.isLinux makeNixAttrs.system then "bash" else "zsh";
in
{
  options.local-ai.modelPath = lib.mkOption {
    type = lib.types.str;
    default = defaultModelPath;
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
          # Pin to NVIDIA GPU only; hide iGPU from this instance.
          # CUDA_VISIBLE_DEVICES selects the GPU for CUDA compute;
          CUDA_VISIBLE_DEVICES = "0";
          GGML_VK_VISIBLE_DEVICES = "-1";
        })
      ];
    };

    # Ensure the shared model dir exists with ollama ownership.
    # Unconditional: the default path isn't inside any StateDirectory,
    # and relocated paths also need creation.
    systemd.tmpfiles.rules = [
      "d ${modelPath} 0750 ollama ollama - -"
    ];

    # Order the primary instance after the backing mount when relocated.
    systemd.services.ollama.unitConfig.RequiresMountsFor =
      lib.mkIf modelsRelocated [ modelPath ];

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

      unitConfig.RequiresMountsFor = lib.mkIf modelsRelocated [ modelPath ];

      environment = {
        OLLAMA_HOST = ollamaVulkanSocket;
        OLLAMA_HOME = "/var/lib/ollama-vulkan";
        OLLAMA_MODELS = modelPath;
        OLLAMA_KEEP_ALIVE = "30m";
        OLLAMA_FLASH_ATTENTION = "1";

        # Hide NVIDIA GPU; force Vulkan on AMD iGPU
        CUDA_VISIBLE_DEVICES = "-1";
        OLLAMA_IGPU_ENABLE = "1";
        OLLAMA_VULKAN = "1";
        VK_DRIVER_FILES = radeonIcd;
      };

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        ExecStart = "${lib.getExe pkgs.unstable.ollama-vulkan} serve";
        Restart = "on-failure";
        RestartSec = 3;

        StateDirectory = "ollama-vulkan";
        WorkingDirectory = "/var/lib/ollama-vulkan";
        ReadWritePaths = [ modelPath ];
      };
    };

    # Disable autostart
    systemd.services.ollama.wantedBy = lib.mkForce [ ];
    systemd.services.open-webui.wantedBy = lib.mkForce [ ];

    programs.${shell}.shellAliases = lib.mkIf cudaSupport {
      ollama-vk = "OLLAMA_HOST=${ollamaVulkanSocket} ollama";
    };
  };
}
