{
  config,
  pkgs,
  ...
}:
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

    hyprWhichKey = {
      enable = true;
      hypr = {
        prettyMods = {
          "SUPER" = "Super";
          "SHIFT" = "Shift";
          "CTRL" = "Ctrl";
          "ALT" = "Alt";
        };
        keyVars = {
          "$mainMod" = "SUPER";
          "$shiftMod" = "SHIFT";
        };
      };
      settings = {
        leaderKey = "$mainMod, space";
        style = {
          anchor = "center";
          background = "#282828d0";
          border = "#4688fa";
          borderWidth = 5;
          cornerRnd = 15;
          color = "#96e9fa";
          font = "JetBrainsMono Nerd Font 24";
          rowsPerColumn = 25;
        };

        menu.groups = {
          apps = {
            key = "a";
            desc = "Apps/Launchers";
          };
          window = {
            key = "w";
            desc = "Window";
          };
          navigation = {
            key = "n";
            desc = "Navigation";
          };
          workspaces = {
            key = "W";
            desc = "Workspaces";
          };
          screenshots = {
            key = "s";
            desc = "Screenshots";
          };
          power = {
            key = "p";
            desc = "Power/Lock";
          };
        };

        menu.submenuGroups = [
          "apps"
          "power"
          "screenshots"
          "window"
        ];

        menu.bindGroups = [
          "apps"
          "navigation"
          "power"
          "screenshots"
          "window"
          "workspaces"
        ];

        menu.items.apps = [
          {
            desc = "Calculator";
            menuKey = "c";
            hyprAction = {
              type = "exec";
              cmd = "rofi -show-icons -combi-modi drun,run -show calc";
            };
          }
          {
            desc = "Emoji Picker";
            menuKey = "e";
            hyprAction = {
              type = "exec";
              cmd = "rofi -show-icons -combi-modi drun,run -show emoji";
            };
          }
          {
            desc = "Firefox";
            menuKey = "f";
            hyprAction = {
              type = "exec";
              cmd = "firefox";
            };
          }
          {
            desc = "Clipboard History";
            menuKey = "h";
            hyprAction = {
              type = "exec";
              cmd = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy";
            };
          }
          {
            desc = "Terminal";
            menuKey = "q";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "q";
            hyprAction = {
              type = "exec";
              cmd = "alacritty";
            };
          }
          {
            desc = "Run";
            menuKey = "r";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "r";
            hyprAction = {
              type = "exec";
              cmd = "rofi -show-icons -combi-modi drun,run -show combi";
            };
          }
          {
            desc = "Tmux";
            menuKey = "t";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "t";
            hyprAction = {
              type = "exec";
              cmd = "alacritty -e tmux new-session -A -s main";
            };
          }
          {
            desc = "Wallpaper select";
            menuKey = "w";
            hyprAction = {
              type = "exec";
              cmd = "waypaper";
            };
          }
          {
            desc = "Yazi";
            menuKey = "y";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "y";
            hyprAction = {
              type = "exec";
              cmd = "alacritty -e yazi";
            };
          }
        ];

        menu.items.power = [
          {
            desc = "Lock (hyprlock)";
            menuKey = "l";
            hyprAction = {
              type = "exec";
              cmd = "hyprlock";
            };
          }
          {
            desc = "Poweroff";
            menuKey = "o";
            hyprAction = {
              type = "exec";
              cmd = "poweroff";
            };
          }
          {
            desc = "Reboot";
            menuKey = "r";
            hyprAction = {
              type = "exec";
              cmd = "reboot";
            };
          }
          {
            desc = "Suspend";
            menuKey = "s";
            hyprAction = {
              type = "exec";
              cmd = "systemctl suspend";
            };
          }
        ];

        menu.items.window = [
          {
            desc = "Close active window";
            menuKey = "c";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "c";
            hyprAction = {
              type = "dispatch";
              dispatch = "killactive";
            };
          }
          {
            desc = "Fullscreen active window";
            menuKey = "f";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "f";
            hyprAction = {
              type = "dispatch";
              dispatch = "fullscreen";
              arg = "1";
            };
          }
          {
            desc = "Toggle floating window";
            menuKey = "l";
            hyprAction = {
              type = "dispatch";
              dispatch = "togglefloating";
            };
          }
          {
            desc = "Pseudo";
            menuKey = "p";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "p";
            hyprAction = {
              type = "dispatch";
              dispatch = "pseudo";
            };
          }
          {
            desc = "Toggle horizontal/vertical";
            menuKey = "T";
            hyprKeyMod = [ "$mainMod" "$shiftMod" ];
            hyprKey = "T";
            hyprAction = {
              type = "dispatch";
              dispatch = "togglesplit";
            };
          }
          {
            desc = "Toggle waybar";
            menuKey = "w";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "w";
            hyprAction = {
              type = "exec";
              cmd = "pkill -SIGUSR1 waybar";
            };
          }
        ];

        menu.items.screenshots = [
          {
            desc = "Window (hyprshot -m window)";
            menuKey = "w";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "PRINT";
            hyprAction = {
              type = "exec";
              cmd = "hyprshot -m window";
            };
          }
          {
            desc = "Output (hyprshot -m output)";
            menuKey = "o";
            hyprKey = "PRINT";
            hyprAction = {
              type = "exec";
              cmd = "hyprshot -m output";
            };
          }
          {
            desc = "Region (hyprshot -m region)";
            menuKey = "r";
            hyprKeyMod = [ "$shiftMod" ];
            hyprKey = "PRINT";
            hyprAction = {
              type = "exec";
              cmd = "hyprshot -m region";
            };
          }
        ];

        menu.items.navigation = [
          {
            desc = "Focus left";
            menuKey = "h";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "h";
            hyprAction = {
              type = "dispatch";
              dispatch = "movefocus";
              arg = "l";
            };
          }
          {
            desc = "Focus down";
            menuKey = "j";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "j";
            hyprAction = {
              type = "dispatch";
              dispatch = "movefocus";
              arg = "d";
            };
          }
          {
            desc = "Focus up";
            menuKey = "k";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "k";
            hyprAction = {
              type = "dispatch";
              dispatch = "movefocus";
              arg = "u";
            };
          }
          {
            desc = "Focus right";
            menuKey = "l";
            hyprKeyMod = [ "$mainMod" ];
            hyprKey = "l";
            hyprAction = {
              type = "dispatch";
              dispatch = "movefocus";
              arg = "r";
            };
          }
          {
            desc = "Move window left";
            menuKey = "H";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "h";
            hyprAction = {
              type = "dispatch";
              dispatch = "movewindow";
              arg = "l";
            };
          }
          {
            desc = "Move window down";
            menuKey = "J";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "j";
            hyprAction = {
              type = "dispatch";
              dispatch = "movewindow";
              arg = "d";
            };
          }
          {
            desc = "Move window up";
            menuKey = "K";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "k";
            hyprAction = {
              type = "dispatch";
              dispatch = "movewindow";
              arg = "u";
            };
          }
          {
            desc = "Move window right";
            menuKey = "L";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "l";
            hyprAction = {
              type = "dispatch";
              dispatch = "movewindow";
              arg = "r";
            };
          }
        ];

        menu.items.workspaces = [
          {
            desc = "Switch to Workspace 1";
            menuKey = "1";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "1";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "1";
            };
          }
          {
            desc = "Switch to Workspace 2";
            menuKey = "2";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "2";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "2";
            };
          }
          {
            desc = "Switch to Workspace 3";
            menuKey = "3";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "3";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "3";
            };
          }
          {
            desc = "Switch to Workspace 4";
            menuKey = "4";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "4";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "4";
            };
          }
          {
            desc = "Switch to Workspace 5";
            menuKey = "5";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "5";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "5";
            };
          }
          {
            desc = "Switch to Workspace 6";
            menuKey = "6";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "6";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "6";
            };
          }
          {
            desc = "Switch to Workspace 7";
            menuKey = "7";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "7";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "7";
            };
          }
          {
            desc = "Switch to Workspace 8";
            menuKey = "8";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "8";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "8";
            };
          }
          {
            desc = "Switch to Workspace 9";
            menuKey = "9";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "9";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "9";
            };
          }
          {
            desc = "Switch to Workspace 10";
            menuKey = "0";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "0";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "10";
            };
          }
          {
            desc = "Move window to WS 1";
            menuKey = "1";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "1";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "1";
            };
          }
          {
            desc = "Move window to WS 2";
            menuKey = "2";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "2";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "2";
            };
          }
          {
            desc = "Move window to WS 3";
            menuKey = "3";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "3";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "3";
            };
          }
          {
            desc = "Move window to WS 4";
            menuKey = "4";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "4";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "4";
            };
          }
          {
            desc = "Move window to WS 5";
            menuKey = "5";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "5";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "5";
            };
          }
          {
            desc = "Move window to WS 6";
            menuKey = "6";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "6";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "6";
            };
          }
          {
            desc = "Move window to WS 7";
            menuKey = "7";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "7";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "7";
            };
          }
          {
            desc = "Move window to WS 8";
            menuKey = "8";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "8";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "8";
            };
          }
          {
            desc = "Move window to WS 9";
            menuKey = "9";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "9";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "9";
            };
          }
          {
            desc = "Move window to WS 10";
            menuKey = "0";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "0";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "10";
            };
          }
          {
            desc = "Workspace next";
            menuKey = "d";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "mouse_down";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "e+1";
            };
          }
          {
            desc = "Workspace prev";
            menuKey = "u";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "mouse_up";
            hyprAction = {
              type = "dispatch";
              dispatch = "workspace";
              arg = "e-1";
            };
          }
          {
            desc = "Toggle scratch";
            menuKey = "s";
            hyprKeyMod = [
              "$mainMod"
            ];
            hyprKey = "s";
            hyprAction = {
              type = "dispatch";
              dispatch = "togglespecialworkspace";
              arg = "magic";
            };
          }
          {
            desc = "Move to scratch";
            menuKey = "S";
            hyprKeyMod = [
              "$mainMod"
              "$shiftMod"
            ];
            hyprKey = "S";
            hyprAction = {
              type = "dispatch";
              dispatch = "movetoworkspace";
              arg = "special:magic";
            };
          }
        ];

        menu.prefixEntries = [
          {
            key = "?";
            desc = "Help";
            submenu = [
              {
                key = "F1";
                desc = "Searchable help";
                cmd = "rofi-help-menu";
              }
              {
                fromGroup = "navigation";
                key = "n";
                desc = "Navigation";
              }
              {
                fromGroup = "workspaces";
                key = "w";
                desc = "Workspaces";
              }
            ];
          }
        ];

        menu.suffixEntries = [ ];
      };

      extraBinds = [
        "$mainMod, F1, exec, rofi-help-menu"
      ];
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
  ];

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

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
