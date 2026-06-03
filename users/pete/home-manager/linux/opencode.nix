{
  lib,
  makeNixAttrs,
  makeNixLib,
  pkgs,
  ...
}:
let
  hasLocalAi = makeNixLib.hasTag "local-ai" (makeNixAttrs.tags or [ ]);

  ollamaClient = lib.optionalAttrs hasLocalAi {
    ollama = {
      type = "openai-compatible";
      apiBase = "http://localhost:11434/v1";
      apiKey = "ollama";
      models = [
        { name = "qwen3-coder:latest"; }
        { name = "qwen3.5:9b"; }
        { name = "jaahas/qwen3.5-uncensored:latest"; }
      ];
    };
  };

in
{
  programs.opencode = {
    enable = true;

    # Override the default pkgs.opencode with the jailed wrapper.
    # The jail provides its own curated PATH so extraPackages is not used.
    package = pkgs.local.jailed-opencode;

    settings = {
      model = "anthropic/claude-sonnet-4-6";
      autoupdate = false; # nix manages the package version

      # Shell inside the jail has no login environment; no -l flag.
      shell = {
        path = "/bin/bash";
        args = [ ];
      };

      # {file:} substitution is resolved by opencode at runtime, so the
      # agenix secret path is never baked into the Nix store.
      providers = {
        anthropic = {
          apiKey = "{file:/run/agenix/anthropic-api-key}";
        };
      } // ollamaClient;
    };

    # Global instructions written to opencode/AGENTS.md
    context = ''
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

    agents = {
      # Focused Nix/HM agent without the make-nix project context
      nix-env = ''
        ---
        model: anthropic/claude-sonnet-4-6
        ---
        You are a helpful assistant specializing in NixOS, Nix-Darwin, and Nix Home
        Manager. Prefer declarative Nix/Home Manager solutions over imperative
        approaches. Start with a single clear path, previewing next steps before
        presenting options. Ask before branching. Explain why solutions work.
      '';

      # make-nix agent: carries full project conventions inline
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
    } // lib.optionalAttrs hasLocalAi {
      local = ''
        ---
        model: ollama/qwen3-coder:latest
        ---
        You are a helpful local assistant running entirely on the user's machine
        with no data leaving the system. You are an expert in GNU core utilities,
        Nix and Home Manager, Bash and POSIX shell scripting, and Linux networking.
        Prefer declarative Nix/Home Manager solutions over imperative approaches.
      '';
    };
  };

  programs.bash = {
    shellAliases = {
      "ocn" = "opencode --agent nix-env";
      "ocm" = "opencode --agent make-nix";
    } // lib.optionalAttrs hasLocalAi {
      "ocl" = "opencode --agent local";
    };

    # Inject the agenix API key at invocation time, matching the aichat pattern.
    # The shell function shadows the bare binary so direct 'opencode' calls also
    # get the key without it being exported into the global environment.
    initExtra = lib.mkAfter # sh
      ''
        opencode() {
          ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) \
            command opencode "$@"
        }
      '';
  };
}
