{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
let
  jail = inputs.jail-nix.lib.init pkgs;

  claude-pkg = config.programs.claude-code.finalPackage;

  jailedClaude = jail "jailed-claude" claude-pkg (
    with jail.combinators;
    [
      network
      time-zone
      mount-cwd
      no-new-session

      (try-readonly (noescape "~/.claude"))
      (try-readwrite (noescape "~/.claude/projects"))
      (try-readwrite (noescape "~/.claude/todos"))
      (try-readwrite (noescape "~/.claude/statsig"))
      (try-readwrite (noescape "~/.claude/sessions"))

      (try-readwrite (noescape "~/.cache"))
      (try-readwrite (noescape "~/.npm"))
      (try-readwrite (noescape "~/.local/share/claude-code"))

      (try-fwd-env "ANTHROPIC_API_KEY")
      (try-fwd-env "CLAUDE_CONFIG_DIR")
      (try-fwd-env "XDG_CONFIG_HOME")
      (try-fwd-env "XDG_DATA_HOME")

      (set-env "SHELL" "${pkgs.bashInteractive}/bin/bash")

      (add-pkg-deps (
        with pkgs;
        [
          bashInteractive
          coreutils
          diffutils
          findutils
          gawk
          git
          gnugrep
          gnused
          gnutar
          gzip
          jq
          ps
          ripgrep
          unzip
          which
        ]
      ))
    ]
  );
in
{
  programs.claude-code = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

    settings = {
      autoUpdaterStatus = "disabled";
      permissions = {
        allow = [ ];
        deny = [ ];
      };
    };

		# context = '' '';

    # Rules: always-loaded, scoped context (like CLAUDE.md but modular)
		# rules = { };

    # Skills: loaded on demand, zero token cost until invoked
    skills = {
      # Inline skill — creates ~/.claude/skills/make-nix/SKILL.md
      make-nix = ''
        ---
        description: Navigate and modify the make-nix framework. Use when working with NixOS host configs, Home Manager modules, tagged configurations, or the make-based build system (attrs.sh, system.sh, home.sh).
        ---

        # make-nix Framework

        ## Architecture
        - makeNixAttrs, makeAttrsCtx, getHomeAttrs are the core functions
        - Tag-based conditional config: validUserTags, validConfigTags
        - Platform discriminator: embeddedTarget field for Pi/RISC-V
        - TGT_USER/TGT_HOST/TGT_SWITCH_USER for cross-user HM deployment

        ## Build commands
        - `make switch` — rebuild and switch NixOS config
        - `make home` — rebuild Home Manager config
        - Tag gating: Hyprland-specific packages behind the `hyprland` tag

        ## Key patterns
        - Config at lowest appropriate level (HM over system)
        - Single source of truth — no logic duplication across layers
        - lib.optionalAttrs + // for conditional attrs, lib.optionals for lists
      '';

      # Directory-based skill — point to a path with SKILL.md + supporting files
			diagnose = ./skills/diagnose;
      grill-with-docs = ./skills/grill-with-docs;
			improve-codebase-architecture = ./skills/improve-codebase-architecture;
			prototype = ./skills/prototype;
			tdd = ./skills/tdd;
			to-issues = ./skills/to-issues;
			to-prd = ./skills/to-prd;	
			triage = ./skills/triage;
			zoom-out = ./skills/zoom-out;

    };

    home.packages = [ jailedClaude ];

    programs.bash = {
      shellAliases = {
        "ccn" = "claude --model claude-sonnet-4-6";
      };

      initExtra = lib.mkAfter ''
        claude() {
          ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) \
            sandboxed -q --allow api.anthropic.com --allow 2607:6bc0::/32 \
            -e ANTHROPIC_API_KEY \
            setpriv --ambient-caps=-sys_nice -- jailed-claude "$@"
        }
      '';
    };
  };
}
