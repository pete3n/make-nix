{ pkgs, jail-nix, ... }:

let
  jail = jail-nix.lib.init pkgs;

  # Tools the agent is allowed to run. Intentionally minimal — expand per project
  # by passing extraPkgs when calling makeJailedOpencode.
  defaultAgentPkgs = with pkgs; [
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
  ];

  # Combinators shared across all opencode jails.
  # Note: no-new-session is intentionally ABSENT — opencode's TUI requires
  # the terminal to be able to receive keyboard input, which --new-session blocks.
  commonCombinators = with jail.combinators; [
    network          # LLM API calls
    time-zone        # Agent timestamps/date tools
    mount-cwd        # Give agent read-write access to the current project only
  ];

in

{
  # Call this to produce a jailed opencode derivation, optionally with
  # project-specific extra tools:
  #
  #   makeJailedOpencode {}
  #   makeJailedOpencode { extraPkgs = [ pkgs.go pkgs.gopls ]; }
  makeJailedOpencode = { extraPkgs ? [] }:
    jail "jailed-opencode" pkgs.opencode (with jail.combinators; (
      commonCombinators ++ [

        # --- Config and persistent data ---
        # Global config: providers, model selection, agents/, plugins/, themes/
        (try-readwrite (noescape "~/.config/opencode"))
        # Session history, message storage, project metadata
        (try-readwrite (noescape "~/.local/share/opencode"))

        # --- API credentials via environment ---
        # Use try-fwd-env so the sandbox doesn't hard-fail if a key isn't set
        (try-fwd-env "ANTHROPIC_API_KEY")
        (try-fwd-env "OPENAI_API_KEY")
        (try-fwd-env "OPENROUTER_API_KEY")
        (try-fwd-env "OPENCODE_CONFIG")      
        (try-fwd-env "OPENCODE_CONFIG_DIR")   
        (try-fwd-env "XDG_CONFIG_HOME")        
        (try-fwd-env "XDG_DATA_HOME")

        # --- Shell for agent bash tool ---
        # opencode spawns a shell to run commands; the base combinator provides
        # /bin/sh but opencode's default shell config wants /bin/bash -l.
        # Override the shell in opencode.json to use /bin/bash (no -l, since
        # there's no login env inside the jail):
        #   { "shell": { "path": "/bin/bash", "args": [] } }
        (set-env "SHELL" "${pkgs.bashInteractive}/bin/bash")

        # --- Agent toolkit ---
        (add-pkg-deps defaultAgentPkgs)
        (add-pkg-deps extraPkgs)
      ]
    ));
}
