# Helper scripts for hyprland config
# TODO: Turn into configurable module with a user preference for each workspace
{ pkgs, ... }:
let
  # Hyprland session restoration script
  hypr-session-restore =
    pkgs.writeShellScriptBin "hypr-session-restore" # sh
      ''
        tmux has-session -t 0 2>/dev/null || tmux new-session -s 0 -d
        hyprctl dispatch exec "[workspace 2] firefox"
        sleep 2
        hyprctl dispatch exec "[workspace 1] alacritty -e tmux attach -t 0"
        hyprctl dispatch workspace 1
      '';
in
{
	home.packages = [
		hypr-session-restore
	];
}
