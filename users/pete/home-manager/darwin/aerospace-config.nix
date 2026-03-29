# Aerospace configuration
# https://nikitabobko.github.io/AeroSpace/guide
{ ... }:
{
  home.file.".config/aerospace/aerospace.toml".text = # toml
    ''
      [mode.main.binding]
      cmd-ctrl-return = 'exec-and-forget alacritty'
      cmd-ctrl-q = 'exec-and-forget alacritty'
      cmd-ctrl-r = 'exec-and-forget alacritty -e fzf-launcher'
      cmd-ctrl-c = 'close'
      cmd-ctrl-f = 'fullscreen'
      cmd-ctrl-h = 'focus left'
      cmd-ctrl-j = 'focus down'
      cmd-ctrl-k = 'focus up'
      cmd-ctrl-l = 'focus right'
      cmd-ctrl-shift-h = 'move left'
      cmd-ctrl-shift-j = 'move down'
      cmd-ctrl-shift-k = 'move up'
      cmd-ctrl-shift-l = 'move right'
      cmd-ctrl-1 = 'workspace 1'
      cmd-ctrl-2 = 'workspace 2'
      cmd-ctrl-3 = 'workspace 3'
      cmd-ctrl-4 = 'workspace 4'
      cmd-ctrl-5 = 'workspace 5'
      cmd-ctrl-shift-1 = 'move-node-to-workspace 1'
      cmd-ctrl-shift-2 = 'move-node-to-workspace 2'
      cmd-ctrl-shift-3 = 'move-node-to-workspace 3'
      cmd-ctrl-shift-4 = 'move-node-to-workspace 4'
      cmd-ctrl-shift-5 = 'move-node-to-workspace 5'
      cmd-ctrl-slash = 'layout tiles horizontal vertical'
      cmd-ctrl-comma = 'layout accordion horizontal vertical'

      [gaps]
      inner.horizontal = 5
      inner.vertical   = 5
      outer.left       = 15
      outer.bottom     = 15
      outer.top        = 15
      outer.right      = 15
    '';
}
