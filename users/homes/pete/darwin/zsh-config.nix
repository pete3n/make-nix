{
  pkgs,
  lib,
  makeNixAttrs,
  ...
}:
{
  programs.zsh =
    let
      tmux_preserve_path =
        lib.optionalString makeNixAttrs.isHomeAlone # sh
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
            		printf "PATH has changed or not yet saved, updating %s\n" "$PATH_STATE_FILE"
            		printf 'PATH="%s"\nexport PATH\n' "''${PATH}" >"$PATH_STATE_FILE"
            	fi
            else
            	# Inside tmux: restore PATH if it doesn't match the saved one
            	if [ -f "$PATH_STATE_FILE" ]; then
            		SAVED_PATH=$(grep '^PATH=' "$PATH_STATE_FILE" | cut -d'"' -f2)

            		if [ "$PATH" != "$SAVED_PATH" ]; then
            			printf "Restoring PATH from %s\n" "$PATH_STATE_FILE"
            			eval "$(cat "$PATH_STATE_FILE")"
            		fi
            	fi
            fi
          '';

      check_fastfetch = # sh
        ''
          # Show fastfetch at login but not for every new TMUX pane/window
          if [ -z "$FASTFETCH_EXECUTED" ] && [ -z "$TMUX" ]; then
          	export FASTFETCH_EXECUTED=1
          	command -v ${pkgs.fastfetch}/bin/fastfetch &> /dev/null &&
          	${pkgs.fastfetch}/bin/fastfetch
          fi
        '';

      no_compfix = # sh
        ''
          # Ignore unsafe directory warnings from Darwin
          ZSH_DISABLE_COMPFIX="true"
        '';

      tmux_ssh_wrapper = # sh
        ''
          # Change the Tmux window name based on the SSH destination host
          # to more easily track open connections
          ssh() {
          	printf "Executing custom ssh wrapper\n"
          	# Check if inside tmux
          	if ps -p $$ -o ppid= | xargs -I {} ps -p {} -o comm= | grep -qw tmux; then
          		# Save the current window name so we can restore it
          		local original_window_name=""
							original_window_name=$(tmux display-message -p '#W')

          		reset_window_name() {
          			tmux rename-window "$original_window_name"
          		}

          		# Trap SIGINT to handle ^C
          		trap reset_window_name SIGINT

          		# Parse and extract the destination host with some really ugly character matching
          		local destination=""
							destination=$(printf '%s\n' "$@" | sed 's/[[:space:]]*\(\(\(-[46AaCfGgKkMNnqsTtVvXxYy]\)\|\(-[^[:space:]]*\([[:space:]]\+[^[:space:]]*\)\?\)\)[[:space:]]*\)*[[:space:]]\+\([^-][^[:space:]]*\).*/\6/')

          		tmux rename-window "$destination"

          		# Execute the SSH command with original args
          		command ssh "$@"
          		local ssh_exit_status=$?

          		# Reset trap to default
          		trap - SIGINT

          		# Check if SSH session exited normally
          		if [ $ssh_exit_status -ne 0 ]; then
          			# SSH failed or was terminated, revert to the original window name
          			tmux rename-window "$original_window_name"
          		else
          			# SSH session ended normally, reset window name to automatic
          			tmux set-window-option automatic-rename "on" 1>/dev/null
          		fi
          	else
          		# We aren't in a tmux session, just run SSH with original args
          		command ssh "$@"
          	fi
          }
        '';

      earlyInit = lib.mkOrder 550 ''
        				${tmux_preserve_path}
                ${no_compfix}
      '';

      afterInit = lib.mkOrder 1000 ''
        				${check_fastfetch}
        				${tmux_ssh_wrapper}
      '';
    in
    {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = false;
      syntaxHighlighting.enable = true;
      defaultKeymap = "viins";
      shellAliases = {
        lsc = "lsd --classic"; # For annoying colors on SMB/NFS mounts
        wl-copy = "pbcopy"; # I use Wayland too much to remember the pb clip cmds
        wl-paste = "pbpaste";
        cd = "z";
      };
      sessionVariables = {
        EDITOR = "nvim";
      };
      oh-my-zsh = {
        enable = true;
        plugins = [
          "docker"
          "docker-compose"
          "colored-man-pages"
          "git"
          "ssh-agent"
          "vi-mode"
        ];
        theme = "robbyrussell";
        extraConfig =
          #Import ssh key TODO: make less imperative
          ''
            zstyle :omz:plugins:ssh-agent identities pete3n
          '';
      };
      initContent = lib.mkMerge [
        earlyInit
        afterInit
      ];
    };
}
