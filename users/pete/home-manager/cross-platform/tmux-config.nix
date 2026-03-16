{
  pkgs,
  lib,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  tmux_ssh_wrapper = # sh
    ''
      ssh() {
        set -u

        _original_window_name=""
        _destination=""
        _skip_next=0
        _ssh_exit=0

        # Parse args to extract destination for tmux window naming
        # Flags listed here take an argument value (per man ssh)
        for _arg in "$@"; do
          if [ "''${_skip_next}" = "1" ]; then
            _skip_next=0
            continue
          fi
          case "''${_arg}" in
            -[bcDEeFIiJLlmopQRSWw])
              _skip_next=1
              ;;
            -*)
              ;;
            *)
              _destination="''${_arg}"
              ;;
          esac
        done

        # Check if we are inside a tmux session
        if [ -n "''${TMUX:-}" ]; then
          _original_window_name=$(tmux display-message -p '#W')

          _reset_window_name() {
            tmux rename-window "''${_original_window_name}"
          }

          trap _reset_window_name INT

          if [ -n "''${_destination}" ]; then
						printf "DEBUG: destination='%s' args='%s'\n" "''${_destination}" "$*" >&2
            tmux rename-window "''${_destination}"
          fi

          command ssh "$@"
          _ssh_exit=$?

          trap - INT

          if [ "''${_ssh_exit}" -ne 0 ]; then
            tmux rename-window "''${_original_window_name}"
          else
            tmux set-window-option automatic-rename "on" 1>/dev/null
          fi
        else
          command ssh "$@"
          _ssh_exit=$?
        fi

        return "''${_ssh_exit}"
      }
    '';
in
{
  home.packages = with pkgs; [ powerline-fonts ];
  programs.tmux = {
    shell =
      if makeNixLib.isDarwin makeNixAttrs.system then "${pkgs.zsh}/bin/zsh" else "${pkgs.bash}/bin/bash";
    enable = true;
    sensibleOnTop = false;
    escapeTime = 10;
    mouse = true;
    plugins = with pkgs.tmuxPlugins; [
      onedark-theme
      pain-control
      vim-tmux-navigator
      logging
      yank
      {
        plugin = tmux-floax;
        extraConfig = ''
          set -g @floax-border-color 'blue'
        '';
      }
      tmux-fzf
      {
        plugin = extrakto;
        extraConfig = ''
          set -g @extrakto_clip_tool "wl-copy"
        '';
      }
      resurrect
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];
    extraConfig = # sh
      ''
        set -g history-limit 50000
        setw -g clock-mode-style 24

        # neovim recommended
        set-option -g focus-events on
        set-option -g default-terminal "screen-256color"
        set-option -sa terminal-features ',alacritty:RGB'

        # List key bindings
        bind b list-keys

        # "Zen" mode - zoom window without status bar
        bind Z if -F '#{window_zoomed_flag}' \
        'resize-pane -Z; set -g status on' \
        'resize-pane -Z; set -g status off'

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
        set -g status-left "#[fg=#282c34,bg=#98c379,bold] #S #{prefix_highlight}#[fg=#98c379,bg=#282c34,nobold,nounderscore,noitalics] #{?window_zoomed_flag,#[fg=#white]Z* ,}"
      '';
  };
  programs.fzf.tmux.enableShellIntegration = true;

  programs.bash = lib.mkIf (makeNixLib.isLinux makeNixAttrs.system) {
    initExtra = tmux_ssh_wrapper;
  };

  programs.zsh = lib.mkIf (makeNixLib.isDarwin makeNixAttrs.system) {
    initContent = lib.mkOrder 1000 tmux_ssh_wrapper;
  };
}
