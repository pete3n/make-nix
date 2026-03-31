# Aerospace configuration
# https://nikitabobko.github.io/AeroSpace/guide
{ config, pkgs, ... }:
let
  smart-close = pkgs.writeShellScript "smart-close" ''
    _focused=$(${pkgs.aerospace}/bin/aerospace list-windows --focused --format "%{app-name} %{window-title}")
    if echo "$_focused" | grep -q "tmux:"; then
      ${pkgs.tmux}/bin/tmux detach-client
    else
      ${pkgs.aerospace}/bin/aerospace close
    fi
  '';
in
{
  programs.aerospace = {
    enable = true;
    launchd.enable = true;
    userSettings = {
      gaps = {
        inner.horizontal = 5;
        inner.vertical = 5;
        outer.left = 5;
        outer.bottom = 5;
        outer.top = 5;
        outer.right = 5;
      };
      mode.main.binding = {
        cmd-enter = "exec-and-forget ${pkgs.alacritty}/bin/alacritty";
        cmd-r = "exec-and-forget ${pkgs.alacritty}/bin/alacritty -e ${config.home.homeDirectory}/.nix-profile/bin/fzf-launcher";
        cmd-t = "exec-and-forget open -n ${pkgs.alacritty}/Applications/Alacritty.app --args -e /bin/sh -c 'source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; source ${config.home.homeDirectory}/.nix-profile/etc/profile.d/hm-session-vars.sh; exec ${pkgs.tmux}/bin/tmux new-session -A -s 0'";
        cmd-shift-q = "exec-and-forget ${smart-close}";
        cmd-f = "fullscreen";
        cmd-h = "focus left";
        cmd-j = "focus down";
        cmd-k = "focus up";
        cmd-l = "focus right";
        cmd-w = "exec-and-forget ${pkgs.writeShellScript "toggle-sketchybar" ''
          if ${pkgs.sketchybar}/bin/sketchybar --query bar | grep -q '"hidden": "off"'; then
            ${pkgs.sketchybar}/bin/sketchybar --bar hidden=on
          else
            ${pkgs.sketchybar}/bin/sketchybar --bar hidden=off
          fi
        ''}";
        cmd-shift-h = "move left";
        cmd-shift-j = "move down";
        cmd-shift-k = "move up";
        cmd-shift-l = "move right";
        cmd-1 = "workspace 1";
        cmd-2 = "workspace 2";
        cmd-3 = "workspace 3";
        cmd-4 = "workspace 4";
        cmd-5 = "workspace 5";
        cmd-shift-1 = "move-node-to-workspace 1";
        cmd-shift-2 = "move-node-to-workspace 2";
        cmd-shift-3 = "move-node-to-workspace 3";
        cmd-shift-4 = "move-node-to-workspace 4";
        cmd-shift-5 = "move-node-to-workspace 5";
        cmd-shift-s = "move-node-to-workspace scratchpad";
        cmd-s = "exec-and-forget ${pkgs.writeShellScript "toggle-scratchpad" ''
          _current=$(${pkgs.aerospace}/bin/aerospace list-workspaces --focused)
          if [ "$_current" = "scratchpad" ]; then
            ${pkgs.aerospace}/bin/aerospace workspace-back-and-forth
          else
            ${pkgs.aerospace}/bin/aerospace workspace scratchpad
          fi
        ''}";
        cmd-slash = "layout tiles horizontal vertical";
        cmd-comma = "layout accordion horizontal vertical";
      };
    };
  };
}
