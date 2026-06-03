{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  jail = inputs.jail-nix.lib.init pkgs;
  claude-pkg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

  claudeSettings = {
    autoUpdaterStatus = "disabled";
    permissions = {
      allow = [ ];
      deny = [ ];
    };
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

  jailedClaude = jail "jailed-claude" claude-pkg (
    with jail.combinators;
    [
      network
      time-zone
      mount-cwd
      no-new-session

      # Inject config directly into the jail from Nix store paths.
      # This avoids resolving HM's two-level symlink chain at runtime
      # and keeps the jail's nix store closure minimal.
      (write-text (noescape "~/.claude/settings.json") (builtins.toJSON claudeSettings))
      (write-text (noescape "~/.claude/CLAUDE.md") contextText)

      # Session history, projects, todos, and credentials
      (try-readwrite (noescape "~/.claude"))

      # npm/node caches for runtime package downloads
      (try-readwrite (noescape "~/.cache"))
      (try-readwrite (noescape "~/.npm"))
      (try-readwrite (noescape "~/.local/share/claude-code"))

      # API credentials — try- variants so the jail doesn't hard-fail
      # if a given key isn't set in the current environment
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
  );

in
{
  home.packages = [ jailedClaude ];

  programs.bash = {
    shellAliases = {
      "ccn" = "claude --model claude-sonnet-4-6";
    };

    # Inject the agenix API key at invocation time and drop the ambient
    # cap_sys_nice capability that interferes with bubblewrap's namespace
    # creation.
    initExtra = lib.mkAfter ''
      claude() {
        ANTHROPIC_API_KEY=$(cat /run/agenix/anthropic-api-key) \
          sandboxed -q --allow api.anthropic.com --allow 2607:6bc0::/32 \
          -e ANTHROPIC_API_KEY \
          setpriv --ambient-caps=-sys_nice -- jailed-claude "$@"
      }
    '';
  };
}
