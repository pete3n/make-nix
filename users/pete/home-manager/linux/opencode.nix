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
  opencode-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

  localProvider = lib.optionalAttrs hasLocalAi {
    ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options = {
        baseURL = "http://localhost:11434/v1";
        apiKey = "ollama";
      };
      models = {
        "gemma4:e4b" = {
          name = "Gemma4 E4B";
        };
        "gemma4:31b" = {
          name = "Gemma4 31b";
        };
        "qwen3-coder:latest" = {
          name = "Qwen3 Coder";
        };
        "qwen3.5:9b" = {
          name = "Qwen3.5 9B";
        };
      };
    };
  };

  opencodeSettings = {
    model = "anthropic/claude-sonnet-4-6";
    autoupdate = false;
    shell = "/bin/bash";
    provider = { }
    // localProvider;
  };

  contextText = ''
    # Global Instructions
		
		You only have access to provided project directories and your API endpoint.
		Any webfetch, curl, research, etc. needs to be performed from the provider server.
		Attempting to access any internet address outside of your API will be blocked and logged.

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

  agentDefs = {
    nix-env = ''
      ---
      model: anthropic/claude-sonnet-4-6
      ---
      You are a helpful assistant specializing in NixOS, Nix-Darwin, and Nix Home
      Manager. Prefer declarative Nix/Home Manager solutions over imperative
      approaches. Start with a single clear path, previewing next steps before
      presenting options. Ask before branching. Explain why solutions work.

    '';

    make-nix = ''
      ---
      model: anthropic/claude-sonnet-4-6
      ---
      You are a helpful assistant for the make-nix configuration framework.
      Prefer declarative Nix/Home Manager solutions over imperative approaches.
      Start with a single clear path. Explain why solutions work.

      # make-nix Project Conventions

      ## Nix Injected Shell Scripts

      Shell variable references inside Nix multiline strings MUST be escaped.
      Use five single-quotes + dollar-brace for variables that must not be
      interpolated at Nix eval time. Nix build-time interpolations use normal
      two-single-quote + dollar-brace syntax.

      Always include a luals language hint comment on the same line as the
      writeShellScriptBin call: pkgs.writeShellScriptBin "name" # sh

      Heredoc syntax (<<EOF) must not be used in Nix injected shell strings.
      Use printf with format strings instead.

      ## Package References

      Any binary not part of pkgs.coreutils must be referenced from nixpkgs.
      Single use: inline the store path. Two or more uses: assign NIX_BINARY
      near the top of the script.

      Exceptions: binaries subject to an intentional command -v check, and
      Nix management tools (nix, nixos-rebuild, home-manager).

      ## Shell Script Conventions

      Default header: set -u. Do not use set -e or pipefail.
      Initialize all internal globals near the top of the script.
      Use dollar-brace-var-colon-dash-brace for optional/external variables.
      Always double-quote variable references to prevent globbing.
      Use printf instead of echo unless there is an explicit reason for echo.

      Variable naming:
      - External / Nix-interpolated: ALL_CAPS_SNAKE_CASE
      - Internal global: lower_snake_case
      - Local / loop iterator: _lower_snake_case (leading underscore)

      ## Nix Patterns

      Prefer lib.optionalAttrs + // for conditional attrsets.
      Prefer lib.optionals for conditional lists.
      Prefer lib.mkIf for conditional module option blocks.
      Avoid rec; lift self-references to let bindings instead.
    '';
  }
  // lib.optionalAttrs hasLocalAi {
    local = ''
      ---
      model: ollama/gemma4:e4b
      ---
      You are a helpful local assistant running entirely on the user's machine
      with no data leaving the system. You are an expert in GNU core utilities,
      Nix and Home Manager, Bash and POSIX shell scripting, and Linux networking.
      Prefer declarative Nix/Home Manager solutions over imperative approaches.
    '';
  };

  jailedOpencode = jail "jailed-opencode" opencode-pkg (
    with jail.combinators;
    [
      network
      time-zone
      mount-cwd
      no-new-session

      # Inject config directly into the jail from Nix store paths.
      # This avoids resolving HM's two-level symlink chain at runtime
      # and keeps the jail's nix store closure minimal.
      (write-text (noescape "~/.config/opencode/opencode.json") (builtins.toJSON opencodeSettings))
      (write-text (noescape "~/.config/opencode/AGENTS.md") contextText)

      # Session history, message storage, project metadata
      (try-readwrite (noescape "~/.local/share/opencode"))
      # npm/bun caches for runtime provider package downloads
      (try-readwrite (noescape "~/.cache"))
      (try-readwrite (noescape "~/.bun"))

      # API credentials — try- variants so the jail doesn't hard-fail
      # if a given key isn't set in the current environment
      (try-fwd-env "ANTHROPIC_API_KEY")
      (try-fwd-env "OPENAI_API_KEY")
      (try-fwd-env "OPENROUTER_API_KEY")
      (try-fwd-env "OPENCODE_CONFIG")
      (try-fwd-env "OPENCODE_CONFIG_DIR")
      (try-fwd-env "XDG_CONFIG_HOME")
      (try-fwd-env "XDG_DATA_HOME")

      (set-env "SHELL" "${pkgs.bashInteractive}/bin/bash")

      (add-pkg-deps (
        with pkgs;
        [
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
        ]
      ))
    ]
    # Agent files injected as individual write-text binds
    ++ lib.mapAttrsToList (
      name: text:
      jail.combinators.write-text (jail.combinators.noescape "~/.config/opencode/agents/${name}.md") text
    ) agentDefs
  );

in
{
  programs.opencode = {
    enable = true;
    package = jailedOpencode;
    settings = opencodeSettings;
    context = contextText;
    agents = agentDefs;
  };

  programs.bash = {
    shellAliases = {
      "ocn" = "opencode --agent nix-env";
      "ocm" = "opencode --agent make-nix";
    }
    // lib.optionalAttrs hasLocalAi {
      "ocl" = "opencode-local";
    };

    # Inject the agenix API key at invocation time and drop the ambient
    # cap_sys_nice capability that interferes with bubblewrap's namespace
    # creation.
    initExtra = lib.mkAfter (
      ''
        opencode() {
          ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) \
            sandboxed -q --allow api.anthropic.com --allow 2607:6bc0::/32 \
            -e ANTHROPIC_API_KEY \
            setpriv --ambient-caps=-sys_nice -- jailed-opencode "$@"
        }
      ''
      + lib.optionalString hasLocalAi ''
        opencode-local() {
        	sandboxed -q 
					setpriv --ambient-caps=-sys_nice -- jailed-opencode --agent local "$@"
        }
      ''
    );
  };
}
