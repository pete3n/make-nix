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

  # Onedark palette
  onedark_colors = {
    black = "#282c34";
    dark_grey = "#3e4452";
    comment = "#5c6370";
    fg = "#abb2bf";
    green = "#98c379";
    yellow = "#e5c07b";
    red = "#e06c75";
  };

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

  # On each prompt, immediately rename the window (so #W updates without waiting for
  # automatic-rename to fire) then re-enable automatic-rename and write the format —
  # all in one tmux invocation. The format keeps automatic-rename functional so that
  # non-shell commands (nvim, htop, …) still show their name when they take the foreground.
  tmux_path_renamer_bash = # sh
    ''
      _tmux_update_window_title() {
        [ -n "''${TMUX:-}" ] || return
        local _path="''${PWD}"
        local _stripped="''${_path#''${HOME}}"
        [ "$_stripped" != "$_path" ] && _path="~$_stripped"
        local _fmt="#{?#{m/r:^(bash)$,#{pane_current_command}},''${_path},#{pane_current_command}}"
        tmux rename-window "$_path" \; \
          set-window-option automatic-rename on \; \
          set-window-option automatic-rename-format "$_fmt"
      }
      PROMPT_COMMAND="''${PROMPT_COMMAND:+''${PROMPT_COMMAND}; }_tmux_update_window_title"
    '';

  tmux_path_renamer_zsh = # zsh
    ''
      _tmux_update_window_title() {
        [[ -n "''${TMUX}" ]] || return
        local _path="''${PWD}"
        local _stripped="''${_path#''${HOME}}"
        [[ "$_stripped" != "$_path" ]] && _path="~$_stripped"
        local _fmt="#{?#{m/r:^(zsh)$,#{pane_current_command}},''${_path},#{pane_current_command}}"
        tmux rename-window "$_path" \; \
          set-window-option automatic-rename on \; \
          set-window-option automatic-rename-format "$_fmt"
      }
      precmd_functions+=(_tmux_update_window_title)
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

      	# Shell hooks rename windows to ~/path; disable app-driven renaming
      	set -g automatic-rename on
      	set -g allow-rename off

      	# List key bindings
      	bind b list-keys

      	# Add zoomed status
      	set -g status-left "#[fg=#282c34,bg=#98c379,bold] #S #{prefix_highlight}#[fg=#98c379,bg=#282c34,nobold,nounderscore,noitalics] #{?window_zoomed_flag,#[fg=white]Z* ,}"

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

      	# --- Status Bar ---
      	set -g status-position top

      	# Base style: fg default lets segments control their own foreground;
      	# bg=default keeps the gaps transparent (blending with terminal bg).
      	set -g status-style "fg=${onedark_colors.fg},bg=default"
      	set -g status-left-length 40
      	set -g status-right-length 60

      	# Left: session name (green pill), optional zoom indicator
      	set -g status-left "#[fg=${onedark_colors.black},bg=${onedark_colors.green},bold] #S #[fg=${onedark_colors.green},bg=default,nobold,nounderscore,noitalics] #{?window_zoomed_flag,[Z] ,}"

      	# Right: time / date / hostname (no trailing decorative segments)
      	set -g status-right "#[fg=${onedark_colors.fg},bg=${onedark_colors.black}] %H:%M  %d %b #[fg=${onedark_colors.black},bg=${onedark_colors.green},bold] #h "

      	# Window list — inactive windows
      	set -g window-status-style          "fg=${onedark_colors.comment},bg=${onedark_colors.black}"
      	set -g window-status-current-style  "fg=${onedark_colors.black},bg=${onedark_colors.green},bold"
      	set -g window-status-activity-style "fg=${onedark_colors.yellow},bg=${onedark_colors.black}"
      	set -g window-status-bell-style     "fg=${onedark_colors.red},bg=${onedark_colors.black},bold"
      	set -g window-status-separator      ""
      	set -g window-status-format         " #I:#W "
      	set -g window-status-current-format " #I:#W "

      	# Message / command prompt
      	set -g message-style         "fg=${onedark_colors.fg},bg=${onedark_colors.dark_grey}"
      	set -g message-command-style "fg=${onedark_colors.fg},bg=${onedark_colors.dark_grey}"

      	set -g pane-border-style        "fg=${onedark_colors.dark_grey},bg=${onedark_colors.black}"
      	set -g pane-active-border-style "fg=${onedark_colors.green},bg=${onedark_colors.black}"

      	# Pane content: dim inactive, normal active
      	set -g window-style        "fg=${onedark_colors.comment}"
      	set -g window-active-style "fg=${onedark_colors.fg}"
    ''
    + lib.optionalString isDarwin ''
      set-option -ga terminal-overrides ',alacritty:Tc:smcup@:rmcup@'
    '';
  };

  programs.fzf.tmux.enableShellIntegration = true;

  programs.bash = lib.mkIf isLinux {
    initExtra = tmux_ssh_wrapper + tmux_path_renamer_bash;
  };

  programs.zsh = lib.mkIf isDarwin {
    initContent = lib.mkOrder 1000 (tmux_ssh_wrapper + tmux_path_renamer_zsh);
  };
}
