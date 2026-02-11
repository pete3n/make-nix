{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkWlrWkCfg =
    {
      anchor,
      background,
      border,
      font,
      menu,
    }:
    lib.generators.toYAML { } {
      inherit
        anchor
        background
        border
        font
        menu
        ;
      inhibit_compositor_keyboard_shortcuts = true;
      auto_kbd_layout = true;
    };

  mkWlrWkMenu =
    {
      name,
    }:
    pkgs.writeShellScriptBin name # sh
      ''
        exec ${lib.getExe pkgs.wlr-which-key} "$@"
      '';

  mkWlrWkItem = item: {
    key = item.menuKey;
    desc = item.desc;
    cmd = mkWlrWkHyprCmd item;
  };

  # Convert an item into the command which-key should execute.
  mkWlrWkHyprCmd =
    item:
    let
      type = item.type or "nop";
      disp =
        "hyprctl dispatch ${item.dispatch}"
        + lib.optionalString ((item ? arg) && item.arg != null) " ${item.arg}";
    in
    if type == "dispatch" then
      disp
    else if type == "exec" then
      item.cmd
    else
      "true"; # nop

  # Hyprland bind line for an action (or null)
  mkWlrWkHyprBind =
    item:
    let
      type = item.type or "nop";
      dispatch =
        "${item.hyprKey}, ${item.dispatch}"
        + lib.optionalString ((item ? arg) && item.arg != null) ", ${item.arg}";
    in
    if !(item ? hyprKey) || item.hyprKey == null then
      null
    else if type == "dispatch" then
      dispatch
    else if type == "exec" then
      "${item.hyprKey}, exec, ${item.cmd}"
    else
      null; # nop does not generate Hypr binds

  validateWlrWkItem =
    item:
    let
      type = item.type or "nop";
      ident = item.desc or (if item ? menuKey then "menuKey=" + toString item.menuKey else "<unknown>");
      die = msg: throw "Action invalid (${ident}): ${msg}";
    in
    if
      !(lib.elem type [
        "nop"
        "exec"
        "dispatch"
      ])
    then
      die "bad type '${type}'"
    else if !(item ? menuKey) then
      die "missing menuKey"
    else if !(item ? desc) then
      die "missing desc"
    else if type == "exec" && !(item ? cmd) then
      die "type=exec missing cmd"
    else if type == "dispatch" && !(item ? dispatch) then
      die "type=dispatch missing dispatch"
    else if (item ? hyprKey) && item.hyprKey == null then
      die "hyprKey is null"
    else if (item ? hyprKey) && item.hyprKey != null && type == "nop" then
      die "type=nop cannot have hyprKey (would create a useless bind); set type=exec/dispatch or remove hyprKey"
    else
      item;

  wlrWkItems = {
    apps = [
      {
        type = "exec";
        menuKey = "c";
        desc = "Calculator";
        cmd = "rofi -show-icons -combi-modi drun,run -show calc";
      }
      {
        type = "exec";
        menuKey = "e";
        desc = "Emoji Picker";
        cmd = "rofi -show-icons -combi-modi drun,run -show emoji";
      }
      {
        type = "exec";
        menuKey = "q";
        hyprKey = "$mainMod, Q";
        desc = "Terminal (Super + q)";
        cmd = "alacritty";
      }
      {
        type = "exec";
        menuKey = "r";
        hyprKey = "$mainMod, R";
        desc = "Run (Super + r)";
        cmd = "rofi -show-icons -combi-modi drun,run -show combi";
      }
      {
        type = "exec";
        menuKey = "t";
        hyprKey = "$mainMod, T";
        desc = "Tmux (Super + t)";
        cmd = "alacritty -e tmux new-session -A -s main";
      }
      {
        type = "exec";
        menuKey = "v";
        hyprKey = "$mainMod, V";
        desc = "Clipboard (Super + v)";
        cmd = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy";
      }
      {
        type = "exec";
        menuKey = "w";
        hyprKey = "$mainMod SHIFT, w";
        desc = "Wallpaper browser (Super + W)";
        cmd = "waypaper";
      }
      {
        type = "exec";
        menuKey = "y";
        hyprKey = "$mainMod, Y";
        desc = "Yazi (Super + y)";
        cmd = "alacritty -e yazi";
      }
    ];
    window = [
      {
        type = "dispatch";
        menuKey = "c";
        hyprKey = "$mainMod, C";
        desc = "Close active window";
        dispatch = "killactive";
      }
      {
        type = "dispatch";
        menuKey = "f";
        hyprKey = "$mainMod, F";
        desc = "Fullscreen active window";
        dispatch = "fullscreen";
        arg = "1";
      }
      {
        type = "dispatch";
        menuKey = "l";
        desc = "Toggle floating window";
        dispatch = "togglefloating";
      }
      {
        type = "dispatch";
        menuKey = "p";
        hyprKey = "$mainMod, P";
        desc = "Pseudo (dwindle)";
        dispatch = "pseudo";
      }
      {
        type = "dispatch";
        menuKey = "t";
        hyprKey = "$mainMod, T";
        desc = "Toggle split (dwindle)";
        dispatch = "togglesplit";
      }
      {
        type = "exec";
        menuKey = "w";
        hyprKey = "$mainMod, W";
        desc = "Toggle waybar";
        cmd = "pkill -SIGUSR1 waybar";
      }
    ];
    lock = [
      {
        type = "exec";
        menuKey = "l";
        hyprKey = "$mainMod SHIFT, l";
        desc = "Lock (hyprlock)";
        cmd = "hyprlock";
      }
    ];
    screenshots = [
      {
        type = "exec";
        menuKey = "w";
        hyprKey = "$mainMod, PRINT";
        desc = "Window (hyprshot -m window)";
        cmd = "hyprshot -m window";
      }
      {
        type = "exec";
        menuKey = "o";
        hyprKey = ", PRINT";
        desc = "Output (hyprshot -m output)";
        cmd = "hyprshot -m output";
      }
      {
        type = "exec";
        menuKey = "r";
        hyprKey = "$shiftMod, PRINT";
        desc = "Region (hyprshot -m region)";
        cmd = "hyprshot -m region";
      }
    ];
    navigation = [
      {
        type = "dispatch";
        menuKey = "h";
        desc = "Focus left   (Super+h)";
        hyprKey = "$mainMod, h";
        dispatch = "movefocus";
        arg = "l";
      }
      {
        type = "dispatch";
        menuKey = "j";
        desc = "Focus down   (Super+j)";
        hyprKey = "$mainMod, j";
        dispatch = "movefocus";
        arg = "d";
      }
      {
        type = "dispatch";
        menuKey = "k";
        desc = "Focus up     (Super+k)";
        hyprKey = "$mainMod, k";
        dispatch = "movefocus";
        arg = "u";
      }
      {
        type = "dispatch";
        menuKey = "l";
        desc = "Focus right  (Super+l)";
        hyprKey = "$mainMod, l";
        dispatch = "movefocus";
        arg = "r";
      }

      {
        type = "dispatch";
        menuKey = "H";
        desc = "Move window left    (Super+Shift+h)";
        hyprKey = "$mainMod SHIFT, h";
        dispatch = "movewindow";
        arg = "l";
      }
      {
        type = "dispatch";
        menuKey = "J";
        desc = "Move window down    (Super+Shift+j)";
        hyprKey = "$mainMod SHIFT, j";
        dispatch = "movewindow";
        arg = "d";
      }
      {
        type = "dispatch";
        menuKey = "K";
        desc = "Move window up      (Super+Shift+k)";
        hyprKey = "$mainMod SHIFT, k";
        dispatch = "movewindow";
        arg = "u";
      }
      {
        type = "dispatch";
        menuKey = "L";
        desc = "Move window right   (Super+Shift+l)";
        hyprKey = "$mainMod SHIFT, l";
        dispatch = "movewindow";
        arg = "r";
      }
    ];
    workspaces = [
      {
        type = "dispatch";
        menuKey = "1";
        desc = "Switch to Workspace 1  (Super+1)";
        hyprKey = "$mainMod, 1";
        dispatch = "workspace";
        arg = "1";
      }
      {
        type = "dispatch";
        menuKey = "2";
        desc = "Switch to Workspace 2  (Super+2)";
        hyprKey = "$mainMod, 2";
        dispatch = "workspace";
        arg = "2";
      }
      {
        type = "dispatch";
        menuKey = "3";
        desc = "Switch to Workspace 3  (Super+3)";
        hyprKey = "$mainMod, 3";
        dispatch = "workspace";
        arg = "3";
      }
      {
        type = "dispatch";
        menuKey = "4";
        desc = "Switch to Workspace 4  (Super+4)";
        hyprKey = "$mainMod, 4";
        dispatch = "workspace";
        arg = "4";
      }
      {
        type = "dispatch";
        menuKey = "5";
        desc = "Switch to Workspace 5  (Super+5)";
        hyprKey = "$mainMod, 5";
        dispatch = "workspace";
        arg = "5";
      }
      {
        type = "dispatch";
        menuKey = "6";
        desc = "Switch to Workspace 6  (Super+6)";
        hyprKey = "$mainMod, 6";
        dispatch = "workspace";
        arg = "6";
      }
      {
        type = "dispatch";
        menuKey = "7";
        desc = "Switch to Workspace 7  (Super+7)";
        hyprKey = "$mainMod, 7";
        dispatch = "workspace";
        arg = "7";
      }
      {
        type = "dispatch";
        menuKey = "8";
        desc = "Switch to Workspace 8  (Super+8)";
        hyprKey = "$mainMod, 8";
        dispatch = "workspace";
        arg = "8";
      }
      {
        type = "dispatch";
        menuKey = "9";
        desc = "Switch to Workspace 9  (Super+9)";
        hyprKey = "$mainMod, 9";
        dispatch = "workspace";
        arg = "9";
      }
      {
        type = "dispatch";
        menuKey = "0";
        desc = "Switch to Workspace 10 (Super+0)";
        hyprKey = "$mainMod, 0";
        dispatch = "workspace";
        arg = "10";
      }
      {
        type = "dispatch";
        menuKey = "1";
        desc = "Move window to ws 1  (Super+Shift+1)";
        hyprKey = "$mainMod SHIFT, 1";
        dispatch = "movetoworkspace";
        arg = "1";
      }
      {
        type = "dispatch";
        menuKey = "2";
        desc = "Move window to ws 2  (Super+Shift+2)";
        hyprKey = "$mainMod SHIFT, 2";
        dispatch = "movetoworkspace";
        arg = "2";
      }
      {
        type = "dispatch";
        menuKey = "3";
        desc = "Move window to ws 3  (Super+Shift+3)";
        hyprKey = "$mainMod SHIFT, 3";
        dispatch = "movetoworkspace";
        arg = "3";
      }
      {
        type = "dispatch";
        menuKey = "4";
        desc = "Move window to ws 4  (Super+Shift+4)";
        hyprKey = "$mainMod SHIFT, 4";
        dispatch = "movetoworkspace";
        arg = "4";
      }
      {
        type = "dispatch";
        menuKey = "5";
        desc = "Move window to ws 5  (Super+Shift+5)";
        hyprKey = "$mainMod SHIFT, 5";
        dispatch = "movetoworkspace";
        arg = "5";
      }
      {
        type = "dispatch";
        menuKey = "6";
        desc = "Move window to ws 6  (Super+Shift+6)";
        hyprKey = "$mainMod SHIFT, 6";
        dispatch = "movetoworkspace";
        arg = "6";
      }
      {
        type = "dispatch";
        menuKey = "7";
        desc = "Move window to ws 7  (Super+Shift+7)";
        hyprKey = "$mainMod SHIFT, 7";
        dispatch = "movetoworkspace";
        arg = "7";
      }
      {
        type = "dispatch";
        menuKey = "8";
        desc = "Move window to ws 8  (Super+Shift+8)";
        hyprKey = "$mainMod SHIFT, 8";
        dispatch = "movetoworkspace";
        arg = "8";
      }
      {
        type = "dispatch";
        menuKey = "9";
        desc = "Move window to ws 9  (Super+Shift+9)";
        hyprKey = "$mainMod SHIFT, 9";
        dispatch = "movetoworkspace";
        arg = "9";
      }
      {
        type = "dispatch";
        menuKey = "0";
        desc = "Move window to ws 10 (Super+Shift+0)";
        hyprKey = "$mainMod SHIFT, 0";
        dispatch = "movetoworkspace";
        arg = "10";
      }
      {
        type = "dispatch";
        menuKey = "d";
        desc = "Workspace next (Super+wheel down)";
        hyprKey = "$mainMod, mouse_down";
        dispatch = "workspace";
        arg = "e+1";
      }
      {
        type = "dispatch";
        menuKey = "u";
        desc = "Workspace prev (Super+wheel up)";
        hyprKey = "$mainMod, mouse_up";
        dispatch = "workspace";
        arg = "e-1";
      }

      {
        type = "dispatch";
        menuKey = "s";
        desc = "Toggle scratch (Super+S)";
        hyprKey = "$mainMod, S";
        dispatch = "togglespecialworkspace";
        arg = "magic";
      }
      {
        type = "dispatch";
        menuKey = "S";
        desc = "Move to scratch (Super+Shift+S)";
        hyprKey = "$mainMod SHIFT, S";
        dispatch = "movetoworkspace";
        arg = "special:magic";
      }
    ];
  };

  wlrWkMenu = [
    {
      key = "?";
      desc = "Help";
      submenu = [
        {
          key = "F1";
          desc = "Searchable help (Super+F1)";
          cmd = "rofi-help-menu";
        }

        {
          key = "n";
          desc = "Navigation";
          submenu = map mkWlrWkItem wlrWkItems.navigation;
        }

        {
          key = "w";
          desc = "Workspaces";
          submenu = map mkWlrWkItem wlrWkItems.workspaces;
        }
      ];
    }
    {
      key = "a";
      desc = "Apps / Launchers";
      submenu = map mkWlrWkItem wlrWkItems.apps;
    }
    {
      key = "w";
      desc = "Window";
      submenu = map mkWlrWkItem wlrWkItems.window;
    }
    {
      key = "s";
      desc = "Screenshots";
      submenu = map mkWlrWkItem wlrWkItems.screenshots;
    }
    {
      key = "l";
      desc = "Lock";
      submenu = map mkWlrWkItem wlrWkItems.lock;
    }
  ];

  wlrWkCfgParams = {
    anchor = "center";
    background = "#282828d0";
    border = "#4688fa";
    font = "JetBrainsMono Nerd Font 24";
    menu = wlrWkMenu;
  };

  wlrWkBin = mkWlrWkMenu {
    name = "wlr-which-key";
  };

  wlrWkCfg = mkWlrWkCfg wlrWkCfgParams;

  # Flatten all action groups you want to generate binds for:
  hyprBindWkItems = map validateWlrWkItem (
    wlrWkItems.apps
    ++ wlrWkItems.lock
    ++ wlrWkItems.navigation
    ++ wlrWkItems.screenshots
    ++ wlrWkItems.window
    ++ wlrWkItems.workspaces
  );

  hyprBindsFromWkItems = lib.filter (bind: bind != null) (map mkWlrWkHyprBind hyprBindWkItems);
in
{
  imports = [
    ./hypr-scripts.nix
    ./rofi-theme.nix
    ./rofi-help-menu.nix
    ./waybar-config.nix
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # All Wayland/Hyprland dependent packages
  home.packages = with pkgs; [
    cliphist # Clipboard manager for wayland with text and image support
    grim # Screecap
    hyprshot # Easy screenshot tool
    hyprsysteminfo
    slurp # Compositor screen selection tool
    waypaper # Wallpaper picker
    wdisplays # Graphical display layout for wayland
    wev # Wayland environment diagnostics
    wl-clipboard # Wayland clipboard
    wlrWkBin
  ];

  programs = {
    swaylock = {
      enable = true;
    };

    hyprSuspendBlocker = {
      enable = true;
      blockers = [
        [ "extPower" ]
      ];
    };

    hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = false;
          ignore_empty_input = true;
        };

        animations = {
          enabled = true;
        };

        # Same keywords as hyprland.conf
        bezier = [
          "linear, 1, 1, 0, 0"
          "easeOut, 0.05, 0.9, 0.1, 1.0"
        ];

        animation = [
          "fadeIn, 1, 3, easeOut"
          "fadeOut, 1, 3, easeOut"
        ];

        background = [
          {
            path = "${config.xdg.userDirs.pictures}/wallpapers/hyprlock.jpg";
          }
        ];

        "input-field" = [
          {
            size = "400, 100";
            position = "0, -80";
            monitor = "";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(202, 211, 245)";
            inner_color = "rgb(0, 0, 0)";
            outer_color = "rgb(24, 25, 38)";
            outline_thickness = 5;
            placeholder_text = "Speak friend...";
            shadow_passes = 2;
          }
        ];
      };
    };

    rofi = {
      enable = true;
      package = pkgs.rofi;
      cycle = true;
      location = "center";
      theme = config.rofi.theme;
      plugins = (
        with pkgs;
        [
          rofi-calc
          rofi-emoji
        ]
      );
      xoffset = 0;
      yoffset = -20;
      extraConfig = {
        show-icons = true;
        kb-cancel = "Escape,Super+space";
        modi = "combi,window,run,calc";
        sort = true;
      };
    };
  };

  services = {
    hyprpolkitagent.enable = true; # Privilege elevation request service
    swww.enable = true; # Wallpaper service

    hyprlidmon = {
      enable = true;
      # rules evaluated on lidClosed only; first match wins
      rules = [
        {
          # "Docked" with AC power and external display attached
          cond = [
            "extPower"
            "extDisplay"
          ];
          closeCmd = [
            "--int-display-disable"
          ];
          openCmd = [
            "--int-display-enable"
          ];
        }
      ];

      # optional defaults if no rule matches
      lidClosedDefaultCmd = "hyprlock";
      lidOpenedDefaultCmd = ":";
    };

    hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on"; # to avoid having to press a key twice to turn on the display.
          ignore_dbus_inhibit = false;
          lock_cmd = "pidof hyprlock || hyprlock"; # avoid starting multiple hyprlock instances.
          #before_sleep_cmd = "loginctl lock-session" # lock before suspend.
        };

        listener = [
          {
            timeout = 150; # 2.5min.
            on-timeout = "brightnessctl -s set 10"; # set monitor backlight to minimum, avoid 0 on OLED monitor.
            on-resume = "brightnessctl -r"; # monitor backlight restore.
          }
          {
            timeout = 150; # 2.5min.
            on-timeout = "brightnessctl -sd rgb:kbd_backlight set 0"; # turn off keyboard backlight.
            on-resume = "brightnessctl -rd rgb:kbd_backlight"; # turn on keyboard backlight.
          }
          {
            timeout = 300; # 5min
            #on-timeout = "loginctl lock-session"; # lock screen when timeout has passed
            on-timeout = "hyprlock"; # lock screen when timeout has passed
          }
          {
            timeout = 330; # 5.5min
            on-timeout = "hyprctl dispatch dpms off"; # screen off when timeout has passed
            on-resume = "hyprctl dispatch dpms on && brightnessctl -r"; # screen on when activity is detected after timeout has fired.
          }
          {
            timeout = 600; # 10min
            on-timeout = "hypr-suspend-blocker";
          }
        ];
      };
    };
  };

  xdg.configFile."wlr-which-key/config.yaml".text = wlrWkCfg;

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    settings = {
      debug = {
        disable_logs = false;
      };
      # Mitigate Xwayland pixelation scaling issues
      xwayland = {
        force_zero_scaling = true;
      };

      exec-once = [
        "wl-paste --type text --watch cliphist store" # Store clipboard text
        "wl-paste --type image --watch cliphist store" # Store clipboard images
        "systemctl --user start hyprpolkitagent"
        "hypr-session-restore"
      ];

      gesture = [
        "3, horizontal, workspace"
      ];

      # List available monitors with: hyprctl monitors
      # Format is: OutputName, resolution, position, scaling
      monitor = [
        "HDMI-A-2,preferred,0x0,1"
        "DP-4,preferred,1920x0,1"
        "DP-5,preferred,5360x0,1"
        ",preferred,auto,1,mirror"
      ];

      input = {
        kb_layout = "us";
        repeat_rate = 50;
        repeat_delay = 300;
        follow_mouse = 2;
        # Follow mouse settings:
        # 0 - cursor movement doesn't change window focus
        # 1 - cursor movement always changes window focus to under the cursor
        # 2 - cursor focus is detached from keyboard focus. Clicking on a window will switch keyboard focus to that window
        # 3 - cursor focus is completely separate from keyboard focus. Clicking on a window will not switch keyboard focus

        sensitivity = 1.0;
        touchpad = {
          natural_scroll = true; # Reverse scroll direction
          scroll_factor = 0.7;
          clickfinger_behavior = true; # 1-finger = LMB, 2-finger = RMB, 3-finger = MMB
          disable_while_typing = true;
        };
      };

      # Execute your favorite apps at launch
      # exec-once = waybar & hyprpaper & firefox
      # Source a file (multi-file configs)
      # source = ~/.config/hypr/myColors.conf

      # Some default env vars.
      "env" = [
        "XCURSOR_SIZE,24"
        # Fix for Nvidia GPU output
        "WLR_NO_HARDWARE_CURSORS,1"
      ];

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for window rules
      # Fix for steam menus
      "windowrulev2" = [
        "stayfocused, title:^()$,class:^(steam)$"
        "minsize 1 1, title:^()$,class:^(steam)$"
      ]
      ++
        # PIP for Firefox video popouts
        [
          "float, title:^(Picture-in-Picture)$"
          "pin, title:^(Picture-in-Picture)$"
          "size 30% 30%, title:^(Picture-in-Picture)$"
          "move 65% 5%, title:^(Picture-in-Picture)$"
        ];

      general = {
        gaps_in = 4;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(7ebae4ee) rgba(5277c3ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        layout = "dwindle";
        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = false;
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;

        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
        # Animations are sped-up from defaults in this config
        "bezier" = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 4, myBezier"
          "windowsOut, 1, 4, default, popin 80%"
          "border, 1, 5, default"
          "borderangle, 1, 6, default"
          "fade, 1, 4, default"
          "workspaces, 1, 4, default"
        ];
      };

      # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
      dwindle = {
        pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true; # you probably want this
      };

      # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
      master = {
        new_status = "master";
      };

      # See https://wiki.hyprland.org/Configuring/Variables/ for more
      misc = {
        force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
      };

      # See https://wiki.hypr.land/Configuring/Binds/ for binds
      "$mainMod" = "SUPER";
      "$shiftMod" = "SHIFT";

      # Binds built from wlr-which-key functions
      bind = [
        "$mainMod, F1, exec, rofi-help-menu"
        "$mainMod, space, exec, ${lib.getExe wlrWkBin}"
      ]
      ++ hyprBindsFromWkItems;
      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
