{
  pkgs,
  lib,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  isDarwin = makeNixLib.isDarwin makeNixAttrs.system;
  isLinux = makeNixLib.isLinux makeNixAttrs.system;
  hasTag = makeNixLib.hasTag;
  tags = makeNixAttrs.tags;

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
    enable = true;
    shell = if isDarwin then "${pkgs.zsh}/bin/zsh" else "${pkgs.bash}/bin/bash";
    sensibleOnTop = false;
    escapeTime = 10;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    historyLimit = 50000;
    clock24 = true;
    focusEvents = true;
    terminal = "screen-256color";

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
        extraConfig =
          if isDarwin then
            ''
              set -g @extrakto_clip_tool "pbcopy"
            ''
          else if hasTag "wayland" tags then
            ''
              set -g @extrakto_clip_tool "wl-copy"
            ''
          else
            ''
              set -g @extrakto_clip_tool "xclip"
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

    extraConfig = ''
      set -g set-titles on
      set -g set-titles-string "tmux: #S"
      set-option -sa terminal-features ',alacritty:RGB'
      set-option -g renumber-windows on

      # List key bindings
      bind b list-keys

      # "Zen" mode - zoom window without status bar
      bind Z if -F '#{window_zoomed_flag}' \
        'resize-pane -Z; set -g status on' \
        'resize-pane -Z; set -g status off'

      # Enter visual selection with vim binding
      bind-key -T copy-mode-vi v send-keys -X begin-selection

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
    ''
    + lib.optionalString isDarwin ''
      set-option -ga terminal-overrides ',alacritty:Tc:smcup@:rmcup@'
    '';
  };

  programs.fzf.tmux.enableShellIntegration = true;

  programs.bash = lib.mkIf isLinux {
    initExtra = tmux_ssh_wrapper;
  };

  programs.zsh = lib.mkIf isDarwin {
    initContent = lib.mkOrder 1000 tmux_ssh_wrapper;
  };
}
