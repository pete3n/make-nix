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

  pi-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

  fullSettings = {
    defaultProvider = "anthropic";
    defaultModel = "claude-sonnet-4-6";
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
            id = "gemma4:e4b";
            name = "Gemma4 E4B (Local)";
            reasoning = false;
            cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
          }
          {
            id = "gemma4:31b";
            name = "Gemma4 31b (Local)";
            reasoning = false;
            cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
          }
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
		
		You only have access to provided project directories and your API endpoint.
		Any webfetch, curl, research, etc. needs to be performed from the provider server.
		Attempting to access any internet address outside of your API will be blocked and logged.
		If you need external resources that aren't available, ask the user to provide them.

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

      # Pi writes auth.json via /login, sessions to the configured sessionDir,
      # and npm packages to ~/.pi/agent/npm/
      (try-readwrite (noescape "~/.pi/agent/auth.json"))
      (try-readwrite (noescape "~/.pi/agent/sessions"))
      (try-readwrite (noescape "~/.pi/agent/npm"))

      # npm/bun caches for runtime package downloads
      (try-readwrite (noescape "~/.cache"))
      (try-readwrite (noescape "~/.bun"))
      (try-readwrite (noescape "~/.npm"))

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
            sandboxed -q --allow api.anthropic.com --allow 2607:6bc0::/32 \
            -e ANTHROPIC_API_KEY -e PI_SKIP_VERSION_CHECK \
            setpriv --ambient-caps=-sys_nice -- jailed-pi "$@"
        }
      ''
      + lib.optionalString hasLocalAi ''
        pi-local() {
          PI_OFFLINE=1 \
            sandboxed -q -e PI_OFFLINE \
						setpriv --ambient-caps=-sys_nice -- jailed-pi "$@"
        }
      ''
    );
  };
}
