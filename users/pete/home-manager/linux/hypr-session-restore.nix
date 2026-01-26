{ pkgs, ... }:

let
  hyprSessionRestore = pkgs.writeShellScriptBin "hypr-session-restore" ''
    tmux has-session -t 0 2>/dev/null || tmux new-session -s 0 -d
    hyprctl dispatch exec "[workspace 2] firefox"
		sleep 2
    hyprctl dispatch exec "[workspace 1] alacritty -e tmux attach -t 0"
    hyprctl dispatch workspace 1
  '';
in
{
  home.packages = [ hyprSessionRestore ];
}
