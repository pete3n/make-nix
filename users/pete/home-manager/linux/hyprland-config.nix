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
        keyVars = {
          "$mainMod" = "SUPER";
          "$shiftMod" = "SHIFT";
        };

        printMods = {
          "SUPER" = "Super";
          "SHIFT" = "Shift";
          "CTRL" = "Ctrl";
          "ALT" = "Alt";
        };

        extraBinds = [
          "$mainMod, F1, exec, rofi-help-menu"
        ];
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
            desc = "Apps/Launchers";
            key = "a";
          };
          display = {
            key = "d";
            desc = "Display";
            submenu = [
              {
                key = "s";
                desc = "Screenshots";
                fromGroup = "screenshots";
              }
              {
                desc = "Wallpaper select";
                key = "w";
                cmd = "waypaper";
              }
            ];

          };
          screenshots = {
            key = "s";
            desc = "Screenshots";
          };
          help = {
            desc = "Help";
            key = "?";
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
          };
          navigation = {
            desc = "Navigation";
            key = "n";
          };
          power = {
            desc = "Power/Lock";
            key = "p";
          };
          window = {
            desc = "Window";
            key = "w";
          };
          workspaces = {
            desc = "Workspaces";
            key = "W";
          };
        };

        menu.order = [
          "help"
          "apps"
          "display"
          "power"
          "window"
        ];

        menu.entries.apps = [
          {
            desc = "Calculator";
            menuKey = "c";
            cmd = "rofi -show-icons -combi-modi drun,run -show calc";
          }
          {
            desc = "Emoji Picker";
            menuKey = "e";
            cmd = "rofi -show-icons -combi-modi drun,run -show emoji";
          }
          {
            desc = "Firefox";
            menuKey = "f";
            cmd = "firefox";
          }
          {
            desc = "Clipboard History";
            menuKey = "h";
            cmd = "cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy";
          }
          {
            desc = "Terminal";
            menuKey = "q";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "q";
              action = {
                type = "exec";
                cmd = "alacritty";
              };
            };
          }
          {
            desc = "Run";
            menuKey = "r";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "r";
              action = {
                type = "exec";
                cmd = "rofi -show-icons -combi-modi drun,run -show combi";
              };
            };
          }
          {
            desc = "Tmux";
            menuKey = "t";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "t";
              action = {
                type = "exec";
                cmd = "alacritty -e tmux new-session -A -s main";
              };
            };
          }
          {
            desc = "Yazi";
            menuKey = "y";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "y";
              action = {
                type = "exec";
                cmd = "alacritty -e yazi";
              };
            };
          }
        ];

        menu.entries.power = [
          {
            desc = "Lock (hyprlock)";
            menuKey = "l";
            cmd = "hyprlock";
          }
          {
            desc = "Poweroff";
            menuKey = "o";
            cmd = "poweroff";
          }
          {
            desc = "Reboot";
            menuKey = "r";
            cmd = "reboot";
          }
          {
            desc = "Suspend";
            menuKey = "s";
            cmd = "systemctl suspend";
          }
        ];

        menu.entries.window = [
          {
            desc = "Close active window";
            menuKey = "c";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "c";
              action = {
                type = "dispatch";
                dispatch = "killactive";
              };
            };
          }
          {
            desc = "Fullscreen active window";
            menuKey = "f";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "f";
              action = {
                type = "dispatch";
                dispatch = "fullscreen";
                arg = "1";
              };
            };
          }
          {
            desc = "Toggle floating window";
            menuKey = "l";
            cmd = "hyprctl dispatch togglefloating";
          }
          {
            desc = "Pseudo";
            menuKey = "p";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "p";
              action = {
                type = "dispatch";
                dispatch = "pseudo";
              };

            };
          }
          {
            desc = "Toggle horizontal/vertical";
            menuKey = "T";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "T";
              action = {
                type = "dispatch";
                dispatch = "togglesplit";
              };

            };
          }
          {
            desc = "Toggle waybar";
            menuKey = "w";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "w";
              action = {
                type = "exec";
                cmd = "pkill -SIGUSR1 waybar";
              };
            };
          }
        ];

        menu.entries.screenshots = [
          {
            desc = "Edit last screenshot (gimp)";
            menuKey = "e";
            cmd = "gimp ${config.xdg.userDirs.pictures}/$(ls ${config.xdg.userDirs.pictures} -t | grep -e 'hyprshot.png' | head -n1)";
          }
          {
            desc = "Output (hyprshot -m output)";
            menuKey = "o";
            hyprBind = {
              key = "PRINT";
              action = {
                type = "exec";
                cmd = "hyprshot -m output";
              };
            };
          }
          {
            desc = "Region (hyprshot -m region)";
            menuKey = "r";
            hyprBind = {
              mods = [ "$shiftMod" ];
              key = "PRINT";
              action = {
                type = "exec";
                cmd = "hyprshot -m region";
              };
            };
          }
          {
            desc = "Window (hyprshot -m window)";
            menuKey = "w";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "PRINT";
              action = {
                type = "exec";
                cmd = "hyprshot -m window";
              };
            };
          }
        ];

        menu.entries.navigation = [
          {
            desc = "Focus left";
            menuKey = "h";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "h";
              action = {
                type = "dispatch";
                dispatch = "movefocus";
                arg = "l";
              };
            };
          }
          {
            desc = "Focus down";
            menuKey = "j";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "j";
              action = {
                type = "dispatch";
                dispatch = "movefocus";
                arg = "d";
              };
            };
          }
          {
            desc = "Focus up";
            menuKey = "k";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "k";
              action = {
                type = "dispatch";
                dispatch = "movefocus";
                arg = "u";
              };
            };
          }
          {
            desc = "Focus right";
            menuKey = "l";
            hyprBind = {
              mods = [ "$mainMod" ];
              key = "l";
              action = {
                type = "dispatch";
                dispatch = "movefocus";
                arg = "r";
              };
            };
          }
          {
            desc = "Move window left";
            menuKey = "H";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "h";
              action = {
                type = "dispatch";
                dispatch = "movewindow";
                arg = "l";
              };
            };
          }
          {
            desc = "Move window down";
            menuKey = "J";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "j";
              action = {
                type = "dispatch";
                dispatch = "movewindow";
                arg = "d";
              };
            };
          }
          {
            desc = "Move window up";
            menuKey = "K";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "k";
              action = {
                type = "dispatch";
                dispatch = "movewindow";
                arg = "u";
              };
            };
          }
          {
            desc = "Move window right";
            menuKey = "L";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "l";
              action = {
                type = "dispatch";
                dispatch = "movewindow";
                arg = "r";
              };
            };
          }
        ];

        menu.entries.workspaces = [
          {
            desc = "Switch to Workspace 1";
            menuKey = "1";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "1";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "1";
              };
            };
          }
          {
            desc = "Switch to Workspace 2";
            menuKey = "2";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "2";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "2";
              };
            };
          }
          {
            desc = "Switch to Workspace 3";
            menuKey = "3";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "3";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "3";
              };
            };
          }
          {
            desc = "Switch to Workspace 4";
            menuKey = "4";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "4";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "4";
              };
            };
          }
          {
            desc = "Switch to Workspace 5";
            menuKey = "5";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "5";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "5";
              };
            };
          }
          {
            desc = "Switch to Workspace 6";
            menuKey = "6";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "6";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "6";
              };
            };
          }
          {
            desc = "Switch to Workspace 7";
            menuKey = "7";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "7";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "7";
              };
            };
          }
          {
            desc = "Switch to Workspace 8";
            menuKey = "8";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "8";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "8";
              };
            };
          }
          {
            desc = "Switch to Workspace 9";
            menuKey = "9";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "9";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "9";
              };
            };
          }
          {
            desc = "Switch to Workspace 10";
            menuKey = "0";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "0";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "10";
              };
            };
          }
          {
            desc = "Move window to WS 1";
            menuKey = "1";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "1";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "1";
              };
            };
          }
          {
            desc = "Move window to WS 2";
            menuKey = "2";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "2";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "2";
              };
            };
          }
          {
            desc = "Move window to WS 3";
            menuKey = "3";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "3";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "3";
              };
            };
          }
          {
            desc = "Move window to WS 4";
            menuKey = "4";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "4";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "4";
              };
            };
          }
          {
            desc = "Move window to WS 5";
            menuKey = "5";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "5";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "5";
              };
            };
          }
          {
            desc = "Move window to WS 6";
            menuKey = "6";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "6";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "6";
              };
            };
          }
          {
            desc = "Move window to WS 7";
            menuKey = "7";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "7";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "7";
              };
            };
          }
          {
            desc = "Move window to WS 8";
            menuKey = "8";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "8";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "8";
              };
            };
          }
          {
            desc = "Move window to WS 9";
            menuKey = "9";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "9";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "9";
              };
            };
          }
          {
            desc = "Move window to WS 10";
            menuKey = "0";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "0";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "10";
              };
            };
          }
          {
            desc = "Workspace next";
            menuKey = "d";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "mouse_down";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "e+1";
              };

            };
          }
          {
            desc = "Workspace prev";
            menuKey = "u";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "mouse_up";
              action = {
                type = "dispatch";
                dispatch = "workspace";
                arg = "e-1";
              };

            };
          }
          {
            desc = "Toggle scratch";
            menuKey = "s";
            hyprBind = {
              mods = [
                "$mainMod"
              ];
              key = "s";
              action = {
                type = "dispatch";
                dispatch = "togglespecialworkspace";
                arg = "magic";
              };
            };
          }
          {
            desc = "Move to scratch";
            menuKey = "S";
            hyprBind = {
              mods = [
                "$mainMod"
                "$shiftMod"
              ];
              key = "S";
              action = {
                type = "dispatch";
                dispatch = "movetoworkspace";
                arg = "special:magic";
              };
            };
          }
        ];
      };
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

      ecosystem = {
        enforce_permissions = true;
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
