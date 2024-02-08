{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    powerline-fonts
  ];
  programs.fzf.tmux.enableShellIntegration = true;
  programs.bash = {
    enable = true;
    initExtra = ''
      # SSH function hook to change the Tmux window name
      ssh() {
      	echo "Executing custom ssh wrapper"
      	# Check if inside tmux
      	if ps -p $$ -o ppid= | xargs -I {} ps -p {} -o comm= | grep -qw tmux; then
      		# Save the current window name so we can restore it
      		local original_window_name=$(tmux display-message -p '#W')

      		reset_window_name() {
      			tmux rename-window "$original_window_name"
      		}

      		# Trap SIGINT to handle ^C
      		trap reset_window_name SIGINT

      		# Parse and extract the destination host
      		local destination=$(echo "$@" | sed 's/[[:space:]]*\(\(\(-[46AaCfGgKkMNnqsTtVvXxYy]\)\|\(-[^[:space:]]*\([[:space:]]\+[^[:space:]]*\)\?\)\)[[:space:]]*\)*[[:space:]]\+\([^-][^[:space:]]*\).*/\6/')

      		# Rename the tmux window to the destination host
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
      			tmux set-window-option automatic-rename "on" 1> /dev/null
      		fi
      	else
      		# Not in tmux, just run SSH with original args
      		command ssh "$@"
      	fi
      }
    '';
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    escapeTime = 10;
    mouse = true;
    plugins = with pkgs; [
      tmuxPlugins.onedark-theme
      tmuxPlugins.pain-control
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.logging
      tmuxPlugins.yank
      tmuxPlugins.tmux-fzf
      {
        plugin = tmuxPlugins.extrakto;
        extraConfig = ''
          set -g @extrakto_clip_tool "wl-copy"
        '';
      }
      tmuxPlugins.resurrect
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];
    extraConfig = ''
         set -g history-limit 50000
         setw -g clock-mode-style 24

         # neovim recommended
         set-option -g focus-events on
         set-option -g default-terminal "screen-256color"
         set-option -sa terminal-features ',alacritty:RGB'

         # List key bindings
         bind b list-keys

				# Enter visual selection with vim binding
				bind-key -T copy-mode-vi v send-keys -X begin-selection

         # Start with 1 for the first window and auto-renumber
         set -g base-index 1
         set-option -g renumber-windows on

         # Use vim keys to navigate selection mode
         set-window-option -g mode-keys vi

         # Split panes in current path
         bind '"' split-window -v -c "#{pane_current_path}"
         bind % split-window -h -c "#{pane_current_path}"
         bind | split-window -h -c "#{pane_current_path}"
         bind _ split-window -v -c "#{pane_current_path}"

          # Transparent status bar on top
         set -g status-bg default
         set -g status-fg default
         set-option -g status-style bg=default
         set -g status-position top

      # Add zoomed status
      set -g status-left "#[fg=#282c34,bg=#98c379,bold] #S #{prefix_highlight}#[fg=#98c379,bg=#282c34,nobold, \
      	nounderscore,noitalics] #{?window_zoomed_flag,#[fg=#white]Z* ,}"
    '';
  };
}
