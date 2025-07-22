{ pkgs, lib, ... }:
let
  floax = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "floax";
    version = "unstable-2024-31-08";
    src = pkgs.fetchFromGitHub {
      owner = "omerxx";
      repo = "tmux-floax";
      rev = "dab0587c5994f3b061a597ac6d63a5c9964d2883";
      sha256 = "sha256-gp/l3SLmRHOwNV3glaMsEUEejdeMHW0CXmER4cRhYD4=";
    };
  };
in
{
  home.packages = with pkgs; [ powerline-fonts ];
  programs.fzf.tmux.enableShellIntegration = true;
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    sensibleOnTop = false;
    escapeTime = 10;
    mouse = true;
    plugins =
      [
        {
          plugin = floax;
          extraConfig = ''
            set -g @floax-border-color 'blue'
          '';
        }
      ]
      ++ (with pkgs.tmuxPlugins; [
        onedark-theme
        pain-control
        vim-tmux-navigator
        logging
        yank
        tmux-fzf
        {
          plugin = extrakto;
          extraConfig = ''
            set -g @extrakto_clip_tool "pbcopy"
          '';
        }
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @ressurect-processes 'ssh bat fzf'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '10'
          '';
        }
      ]);
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
