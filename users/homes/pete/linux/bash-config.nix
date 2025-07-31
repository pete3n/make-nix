# This file contains unique username based configuration options
{
  config,
  lib,
  make_opts,
  ...
}:
let
  tmux_preserve_path =
    lib.optionalString make_opts.isHomeAlone # sh
      ''
        # For non-NixOS or Nix-Darwin systems preserve PATH for tmux.
        # Determine path to store saved PATH
        if [ -n "$XDG_STATE_HOME" ]; then
        	PATH_STATE_DIR="$XDG_STATE_HOME"
        else
        	PATH_STATE_DIR="$HOME/.local/state"
        fi

        PATH_STATE_FILE="$PATH_STATE_DIR/.nix-path.env"

        # Ensure the directory exists
        mkdir -p "$PATH_STATE_DIR"

        # If not inside tmux, save the current PATH if it differs from the saved one
        if [ -z "$TMUX" ]; then
        	if [ -f "$PATH_STATE_FILE" ]; then
        		SAVED_PATH=$(grep '^PATH=' "$PATH_STATE_FILE" | cut -d'"' -f2)
        	else
        		SAVED_PATH=""
        	fi

        	if [ "$PATH" != "$SAVED_PATH" ]; then
        		printf 'PATH="%s"\nexport PATH\n' "$PATH" >"$PATH_STATE_FILE"
        	fi
        else
        	# Inside tmux: restore PATH if it doesn't match the saved one
        	if [ -f "$PATH_STATE_FILE" ]; then
        		SAVED_PATH=$(grep '^PATH=' "$PATH_STATE_FILE" | cut -d'"' -f2)

        		if [ "$PATH" != "$SAVED_PATH" ]; then
        			eval "$(cat "$PATH_STATE_FILE")"
        		fi
        	fi
        fi
      '';
  sudo_wrapper =
    lib.optionalString make_opts.isHomeAlone # sh
      ''
        # sudo wrapper do workaround missing path for commands when run as sudo
        sudo() {
        	if [ $# -eq 0 ]; then
        		command sudo
        	else
        		cmd=$(realpath "$(command -v "$1")")
        		shift
        		command sudo "$cmd" "$@"
        	fi
        }
      '';
in
{
  programs.bash = {
    enableCompletion = true;
    shellAliases = {
      cd = "z";
      home-manager-rollback = "home-manager generations | fzf | awk -F '-> ' '{print \$2 \"/activate\"}'";
      screenshot = "grim";
      lsc = "lsd --classic";
    };
    initExtra = # sh
      ''
        set -o vi
      ''
      + tmux_preserve_path
      + sudo_wrapper;

    profileExtra = # sh
      ''
        export EDITOR=nvim
        if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
        	command -v fastfetch &> /dev/null && fastfetch
        	export FASTFETCH_EXECUTED=1
        	echo
        	ip link
        	echo
        	ip -br a
        	echo
        fi
        # Workaround for xdg.userDirs bug always being set to false
        source "${config.home.homeDirectory}/.config/user-dirs.dirs"
      '';
  };
}
