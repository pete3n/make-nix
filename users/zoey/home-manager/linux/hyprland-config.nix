{
  config,
  lib,
  ...
}:
{
  services.zoeyChar = {
    enable = true;
    imageDir = "${config.xdg.userDirs.pictures}/chars";
    audioDir = "${config.home.homeDirectory}/Audio/chars";
    displayDuration = 4;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = false;

    settings = {
      exec-once = [
        "zoey-char"
      ];

      monitor = [
        ",preferred,auto,1"
      ];

      input = {
        kb_layout = "us";
        repeat_rate = 25;
        repeat_delay = 600;
        touchpad = {
          disable_while_typing = false;
        };
      };

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 0;
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
        shadow.enabled = false;
        blur.enabled = false;
      };

      animations.enabled = false;

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      "windowrulev2" = [
        "float, class:^(char-popout)$"
        "center, class:^(char-popout)$"
        "noborder, class:^(char-popout)$"
        "noshadow, class:^(char-popout)$"
        "noanim, class:^(char-popout)$"
        "opacity 1.0 1.0, class:^(char-popout)$"
        "noinitialfocus, class:^(char-popout)$"
        "size 1200 1200, class:^(char-popout)$"
      ];

      # Parent escape hatch - works outside submap
      bind = [
        "SUPER ALT CTRL, F12, exec, hyprctl dispatch exit"
      ];
    };

    extraConfig =
      let
        keys = [
          "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m"
          "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
          "0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
          "space" "return"
        ];
        mkBind = k: "bind = , ${k}, exec, zoey-char -c '${k}'";
        binds = lib.concatStringsSep "\n" (map mkBind keys);
      in
      ''
        submap = toddler
        ${binds}
        bind = SUPER ALT CTRL, SPACE, exec, hyprctl dispatch exit
        submap = reset

        submap = reset
        bind = , catchall, submap, toddler
        submap = reset
      '';
  };
}
