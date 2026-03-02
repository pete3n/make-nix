# Helper scripts for hyprland config
{ pkgs, ... }:
let
  hypr-session-restore =
    pkgs.writeShellScriptBin "hypr-session-restore" # sh
    ''
      set -u

      NIX_HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
      NIX_JQ="${pkgs.jq}/bin/jq"
      NIX_TMUX="${pkgs.tmux}/bin/tmux"

      "''${NIX_TMUX}" new-session -A -s main -d

      have_client() {
        # $1 = regex (case-insensitive) to match class or initialTitle/title
        "''${NIX_HYPRCTL}" clients -j | "''${NIX_JQ}" -e --arg re "''${1}" '
          any(.[]; ((.class // "") | test($re; "i")) or
                 ((.title // "") | test($re; "i")) or
                 ((.initialTitle // "") | test($re; "i")))
        ' >/dev/null 2>&1
      }

      # Launch Firefox on workspace 2 only if not already present
      _firefox_regex="^(firefox|org\\.mozilla\\.firefox)$"
      # Matches Firefox by class name or bundle identifier
      if ! have_client "''${_firefox_regex}"; then
        "''${NIX_HYPRCTL}" dispatch exec "[workspace 2] firefox"
      fi

      # Launch Alacritty+tmux on workspace 1 only if not already present
      _alacritty_regex="^(Alacritty|alacritty)$"
      # Matches Alacritty by class name (case variants)
      if ! have_client "''${_alacritty_regex}"; then
        "''${NIX_HYPRCTL}" dispatch exec "[workspace 1] alacritty -e ''${NIX_TMUX} attach -t 0"
      fi

      # Focus workspace 1
      "''${NIX_HYPRCTL}" dispatch workspace 1
    '';
in
{
  home.packages = [
    pkgs.jq
    hypr-session-restore
  ];
}
