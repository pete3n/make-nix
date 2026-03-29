{ pkgs, ... }:
let
  fzf-launcher = pkgs.writeShellScriptBin "fzf-launcher" # bash
    ''
      #!/usr/bin/env bash
      # Get all applications from standard locations
      _apps=$(
        find /Applications /System/Applications ~/Applications \
          -maxdepth 2 -name "*.app" -type d 2>/dev/null \
          | sed 's|.*/||; s|\.app$||' \
          | sort -u
      )

      _selection=$(printf '%s\n' "$_apps" | \
        ${pkgs.fzf}/bin/fzf \
          --prompt="Launch: " \
          --layout=reverse \
          --border \
          --height=40% \
          --no-multi)

      [ -n "$_selection" ] && open -a "$_selection"
    '';
in
{
  home.packages = [ fzf-launcher ];

  home.file.".config/aerospace/aerospace.toml".text = ''
    # Aerospace configuration
    # https://nikitabobko.github.io/AeroSpace/guide

    [mode.main.binding]
    # Terminal
    alt-return = 'exec-and-forget alacritty'

    # Launcher
    alt-d = 'exec-and-forget ${fzf-launcher}/bin/fzf-launcher'

    # Close window
    alt-c = 'close'

    # Toggle fullscreen
    alt-f = 'fullscreen'

    # Focus
    alt-h = 'focus left'
    alt-j = 'focus down'
    alt-k = 'focus up'
    alt-l = 'focus right'

    # Move
    alt-shift-h = 'move left'
    alt-shift-j = 'move down'
    alt-shift-k = 'move up'
    alt-shift-l = 'move right'

    # Workspaces
    alt-1 = 'workspace 1'
    alt-2 = 'workspace 2'
    alt-3 = 'workspace 3'
    alt-4 = 'workspace 4'
    alt-5 = 'workspace 5'

    # Move window to workspace
    alt-shift-1 = 'move-node-to-workspace 1'
    alt-shift-2 = 'move-node-to-workspace 2'
    alt-shift-3 = 'move-node-to-workspace 3'
    alt-shift-4 = 'move-node-to-workspace 4'
    alt-shift-5 = 'move-node-to-workspace 5'

    # Layout
    alt-slash = 'layout tiles horizontal vertical'
    alt-comma = 'layout accordion horizontal vertical'

    [gaps]
    inner.horizontal = 5
    inner.vertical   = 5
    outer.left       = 15
    outer.bottom     = 15
    outer.top        = 15
    outer.right      = 15
  '';
}
