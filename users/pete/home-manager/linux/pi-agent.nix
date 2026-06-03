{
  inputs,
  lib,
  makeNixAttrs,
  makeNixLib,
  pkgs,
  ...
}:
let
  hasLocalAi = makeNixLib.hasTag "local-ai" (makeNixAttrs.tags or [ ]);

  jail = inputs.jail-nix.lib.init pkgs;

  pi-pkg = inputs.llm-agents.packages.${pkgs.system}.pi;

  fullSettings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-sonnet-4-20250514";
    defaultThinkingLevel = "medium";
    enableInstallTelemetry = false;
    quietStartup = true;
    theme = "dark";
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 20000;
    };
  };

  fullModels = lib.optionalAttrs hasLocalAi {
    providers = {
      ollama = {
        baseUrl = "http://localhost:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
        models = [
          {
            id = "qwen3-coder:latest";
            name = "Qwen3 Coder (Local)";
            reasoning = false;
            cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
          }
          {
            id = "qwen3.5:9b";
            name = "Qwen3.5 9B (Local)";
            reasoning = false;
            cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
          }
        ];
      };
    };
  };

  contextText = ''
    # Global Instructions

    You are operating inside the Alacritty terminal emulator on systems running
    NixOS, Nix-Darwin, or other Linux distributions using Nix Home Manager.
    Sessions may run inside Tmux, within a Wayland/Hyprland graphical environment
    on Linux, or on macOS with Nix-Darwin.

    You are an expert in GNU core utilities, Nix and Home Manager, Bash and POSIX
    shell scripting, and Linux networking. Where applicable, prefer declarative
    Nix/Home Manager solutions over imperative approaches.

    When providing solutions, start with a single clear path rather than presenting
    multiple options upfront. If further steps are needed, preview the next step or
    provide a brief summary of the plan. When a decision point requires branching,
    ask the user which path to take and include your recommended option.

    Responses should facilitate learning — accompany solutions with explanations of
    why they work, not just what to run.
  '';

  jailedPi = jail "jailed-pi" pi-pkg (with jail.combinators;
    [
      network
      time-zone
      mount-cwd
      no-new-session

      # Inject config directly into the jail from Nix store paths.
      # Pi uses ~/.pi/agent/ for all config, auth, sessions, and packages.
      (write-text (noescape "~/.pi/agent/settings.json") (builtins.toJSON fullSettings))
      (write-text (noescape "~/.pi/agent/AGENTS.md") contextText)

      # Session history, auth storage, installed packages — readwrite
      (try-readwrite (noescape "~/.pi/agent"))
      # npm/bun caches for runtime package downloads
      (try-readwrite (noescape "~/.cache"))
      (try-readwrite (noescape "~/.bun"))
      (try-readwrite (noescape "~/.npm"))

      # Agenix secret accessible inside the jail
      (try-readonly "/run/agenix/anthropic-api-key")

      # Environment forwarding
      (try-fwd-env "ANTHROPIC_API_KEY")
      (try-fwd-env "OPENAI_API_KEY")
      (try-fwd-env "PI_OFFLINE")
      (try-fwd-env "PI_SKIP_VERSION_CHECK")
      (try-fwd-env "PI_TELEMETRY")
      (try-fwd-env "PI_PACKAGE_DIR")
      (try-fwd-env "PI_CODING_AGENT_SESSION_DIR")

      (set-env "SHELL" "${pkgs.bashInteractive}/bin/bash")

      (add-pkg-deps (with pkgs; [
        bashInteractive
        coreutils
        git
        curl
        wget
        jq
        ripgrep
        gnugrep
        findutils
        diffutils
        gawk
        gnutar
        gzip
        unzip
        which
        ps
      ]))
    ]
    # models.json injected only when local-ai models are configured
    ++ lib.optional (fullModels != { })
      (jail.combinators.write-text
        (jail.combinators.noescape "~/.pi/agent/models.json")
        (builtins.toJSON fullModels))
  );

in
{
  imports = [ ./pi-agent-module.nix ];

  programs.pi-agent = {
    enable = true;
    package = jailedPi;
    settings = fullSettings;
    models = fullModels;
    context = contextText;
  };

  programs.bash = {
    shellAliases = lib.optionalAttrs hasLocalAi {
      "pl" = "pi-local";
    };

    initExtra = lib.mkAfter (
      ''
        pi() {
          ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) \
          PI_SKIP_VERSION_CHECK=1 \
            setpriv --ambient-caps=-sys_nice -- jailed-pi "$@"
        }
      ''
      + lib.optionalString hasLocalAi ''
        pi-local() {
          PI_OFFLINE=1 \
            sandboxed -q setpriv --ambient-caps=-sys_nice -- jailed-pi "$@"
        }
      ''
    );
  };
}
