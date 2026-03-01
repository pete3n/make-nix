{
	lib,
  pkgs,
  ...
}:
let
  aichatWrapper = pkgs.writeShellScriptBin "aichat-ctx" # sh
    ''
      set -u

      WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-}
      DISPLAY=''${DISPLAY:-}
      TMUX=''${TMUX:-}
      TERM_PROGRAM=''${TERM_PROGRAM:-}

      os_info=""
      hyprland_info=""
      context=""

      if [ "$(uname -s)" = "Darwin" ]; then
        os_info=$(sw_vers | tr '\n' ' ')
      else
        os_info=$(${pkgs.gnugrep}/bin/grep ^PRETTY_NAME /etc/os-release | cut -d= -f2)
      fi

      if command -v hyprctl &>/dev/null && hyprctl version &>/dev/null 2>&1; then
        hyprland_info=$(hyprctl version)
      else
        hyprland_info="not running"
      fi

      context=$(printf "Kernel: %s\nOS: %s\nShell: %s\nTerminal: %s\nCompositor: %s / %s\nTmux: %s\nHyprland: %s\nNix: %s\n" \
        "$(uname -a)" \
        "''${os_info}" \
        "''${SHELL}" \
        "''${TERM_PROGRAM:-unknown}" \
        "''${WAYLAND_DISPLAY:-none}" \
        "''${DISPLAY:-none}" \
        "''${TMUX:+yes}" \
        "''${hyprland_info}" \
        "$(nix --version)")

      exec ${pkgs.aichat}/bin/aichat "$@" \
        --prompt "System context:
      ''${context}"
    '';
in
{
  programs.aichat = {
    enable = true;
    settings = {
      model = "claude:claude-sonnet-4-6";
      clients = [
        { type = "claude"; }
      ];
    };
  };

  home.file.".config/aichat/roles/nix-env.yaml".text = ''
    name: nix-env
    prompt: |
      You are a helpful assistant operating inside the Alacritty terminal emulator on
      systems running NixOS, Nix-Darwin, or other Linux distributions using Nix Home
      Manager. Sessions may run inside Tmux, within a Wayland/Hyprland graphical
      environment on Linux, or on macOS with Nix-Darwin. The user's shell is Bash.

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

  home.file.".config/aichat/contexts/make-nix.md".text = ''
    # make-nix Project Context

    This project manages Nix configurations for NixOS, Nix-Darwin, and Nix Home Manager
    across multiple systems. Configurations are declarative and version controlled in a
    public GitHub repository.

    ## Nix Injected Shell Script Instructions

    ### Language Hint
    Always include a luals language hint comment between the function call and the opening
    quotes. Format as:
      pkgs.writeShellScriptBin "name" # sh\n\t''''\n\t\t...\n\t'''';
    Rule: comment on same line as function call, opening '''' on next line with one tab
    indent, script body indented one additional tab, closing '''' at one tab indent.

    ### Package References
    Any binary not part of pkgs.coreutils should be referenced from nixpkgs:
      grep -> ''${pkgs.gnugrep}/bin/grep
    If a reference is used two or more times, define a variable near the top of the
    script with the format NIX_BINARY where BINARY is the executable name.

    Exceptions:
    - Binaries that are the subject of an intentional command -v availability check
      must not be referenced via nixpkgs.
    - Exclude binaries that are implicit dependencies of the Nix build environment
      or are themselves Nix management tools (e.g. nix, nixos-rebuild, home-manager).

    ### Heredoc Restriction
    Heredoc syntax (<<EOF ... EOF) must not be used in Nix injected shell strings.
    The heredoc delimiter conflicts with Nix multiline string parsing, causing
    interpolation errors and breaking LSP highlighting from the heredoc onward.

    Rule: Use printf with format strings as the replacement for heredocs:
      output=$(printf "%s\n%s\n" \
        "''${var_one}" \
        "''${var_two}")

    ## POSIX Shell Variable Conventions

    ### Defensive Programming
    Default header for all injected shell scripts:
      set -u
    - Do not use set -e or pipefail.
    - Initialize all internal global variables near the top of the script (var="").
    - Use ''${var:-} or ''${var:-default} for optional or externally sourced variables.
    - Use explicit || error handling where pipeline or command failures need handling.

    ### Variable Scopes
    1. External (environment or Nix interpolation):
       - Format: ALL_CAPS_SNAKE_CASE
       - Declare near top of script
       - Example: WAYLAND_DISPLAY, NIX_BINARY

    2. Internal global (script-wide scope):
       - Format: lower_snake_case
       - Declare near top, initialize as var="" if no immediate value
       - Example: os_info="", hyprland_info=""

    3. Local (function-scoped or loop iterators):
       - Format: _lower_snake_case (leading underscore)
       - Declare in place, use descriptive names over single letters
       - Example: _index=1, _line=""

    ### Formatting
    - All variable references use ''${var} syntax rather than $var.
    - In Nix injected shell strings, runtime variables must be escaped as ''${var}.
    - Nix build-time interpolations use normal ''${} syntax without escaping.
  '';

  home.packages = [ aichatWrapper ];

  programs.bash = {
    shellAliases = {
      "??"  = "aichat-ctx --role nix-env";
      "???" = "aichat-ctx --role nix-env --file ~/.config/aichat/contexts/make-nix.md --session make-nix";
    };
    initExtra = lib.mkAfter # sh
      ''
        export CLAUDE_API_KEY=$(cat /run/agenix/anthropic-api-key)
      '';
  };
}
