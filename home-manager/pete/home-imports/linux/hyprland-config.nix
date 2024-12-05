{
  outputs,
  pkgs,
  config,
  ...
}:
let
  inherit (config.lib.formats.rasi) mkLiteral;
  rofi-theme = {
    "*" = {
      selected-normal-foreground = mkLiteral "#ffffff";
      foreground = mkLiteral "#ffffff";
      normal-foreground = mkLiteral "@foreground";
      alternate-normal-background = mkLiteral "transparent";
      red = mkLiteral "#ff322f";
      selected-urgent-foreground = mkLiteral "#ffc39c";
      blue = mkLiteral "#278bd2";
      urgent-foreground = mkLiteral "#f3843d";
      alternate-urgent-background = mkLiteral "transparent";
      active-foreground = mkLiteral "#268bd2";
      lightbg = mkLiteral "#eee8d5";
      selected-active-foreground = mkLiteral "#205171";
      alternate-active-background = mkLiteral "transparent";
      background = mkLiteral "transparent";
      bordercolor = mkLiteral "#393939";
      alternate-normal-foreground = mkLiteral "@foreground";
      normal-background = mkLiteral "transparent";
      lightfg = mkLiteral "#586875";
      selected-normal-background = mkLiteral "#268bd2";
      border-color = mkLiteral "@foreground";
      spacing = mkLiteral "2";
      separatorcolor = mkLiteral "#268bdb";
      urgent-background = mkLiteral "transparent";
      selected-urgent-background = mkLiteral "#268bd2";
      alternate-urgent-foreground = mkLiteral "@urgent-foreground";
      background-color = mkLiteral "#00000000";
      alternate-active-foreground = mkLiteral "@active-foreground";
      active-background = mkLiteral "#0a0047";
      selected-active-background = mkLiteral "#268bd2";
    };

    # Holds the entire window
    "window" = {
      background-color = mkLiteral "#393939cc";
      border = mkLiteral "1";
      padding = mkLiteral "5";
    };

    # Wrapper around bar and results
    "mainbox" = {
      border = mkLiteral "0";
      padding = mkLiteral "0";
    };

    "textbox" = {
      text-color = mkLiteral "@foreground";
    };

    # Command prompt left of the input
    "#prompt" = {
      enabled = false;
    };

    # Actual text box
    "#entry" = {
      placeholder-color = mkLiteral "#00ff00";
      expand = true;
      horizontal-align = "0";
      placeholder = "";
      padding = mkLiteral "0px 0px 0px 5px";
      blink = true;
    };

    # Top bar
    "#inputbar" = {
      children = map mkLiteral [
        "prompt"
        "entry"
      ];
      border = mkLiteral "1px";
      border-radius = mkLiteral "4px";
      padding = mkLiteral "6px";
    };

    # Results
    "listview" = {
      fixed-height = mkLiteral "0";
      border = mkLiteral "2px dash 0px 0px";
      border-color = mkLiteral "@separatorcolor";
      spacing = mkLiteral "2px";
      scrollbar = mkLiteral "true";
      padding = mkLiteral "2px 0px 0px";
    };

    # Each result
    "element" = {
      border = mkLiteral "0";
      padding = mkLiteral "1px";
    };

    "element.normal.normal" = {
      background-color = mkLiteral "@normal-background";
      text-color = mkLiteral "@normal-foreground";
    };

    "element.normal.urgent" = {
      background-color = mkLiteral "@urgent-background";
      text-color = mkLiteral "@urgent-foreground";
    };

    "element.normal.active" = {
      background-color = mkLiteral "@active-background";
      text-color = mkLiteral "@active-foreground";
    };

    "element.selected.normal" = {
      background-color = mkLiteral "@selected-normal-background";
      text-color = mkLiteral "@selected-normal-foreground";
    };

    "element.selected.urgent" = {
      background-color = mkLiteral "@selected-urgent-background";
      text-color = mkLiteral "@selected-urgent-foreground";
    };

    "element.selected.active" = {
      background-color = mkLiteral "@selected-active-background";
      text-color = mkLiteral "@selected-active-foreground";
    };

    "element.alternate.normal" = {
      background-color = mkLiteral "@alternate-normal-background";
      text-color = mkLiteral "@alternate-normal-foreground";
    };

    "element.alternate.urgent" = {
      background-color = mkLiteral "@alternate-urgent-background";
      text-color = mkLiteral "@alternate-urgent-foreground";
    };

    "element.alternate.active" = {
      background-color = mkLiteral "@alternate-active-background";
      text-color = mkLiteral "@alternate-active-foreground";
    };

    "scrollbar" = {
      witdh = mkLiteral "4px";
      border = mkLiteral "0";
      handle-width = mkLiteral "8px";
      padding = mkLiteral "0";
    };

    "mode-switcher" = {
      border = mkLiteral "2px dash 0px 0px";
      border-color = mkLiteral "@separatorcolor";
    };

    "button.selected" = {
      background-color = mkLiteral "@selected-normal-background";
      text-color = mkLiteral "@selected-normal-foreground";
    };

    "button" = {
      background-color = mkLiteral "@selected-normal-background";
      text-color = mkLiteral "@selected-normal-foreground";
    };

    "inputbar" = {
      spacing = mkLiteral "0";
      text-color = mkLiteral "@normal-foreground";
      padding = mkLiteral "1px";
      children = mkLiteral "[ prompt,textbox-prompt-colon,entry,case-indicator ]";
    };

    "case-indicator" = {
      spacing = mkLiteral "0";
      text-color = mkLiteral "@normal-foreground";
    };

    "entry" = {
      spacing = mkLiteral "0";
      text-color = mkLiteral "@normal-foreground";
    };

    "prompt" = {
      spacing = mkLiteral "0";
      text-color = mkLiteral "@normal-foreground";
    };

    "textbox-prompt-colon" = {
      expand = mkLiteral "false";
      str = ":";
      margin = mkLiteral "0px 0.3em 0em 0em";
      text-color = mkLiteral "@normal-foreground";
    };

    "element-text" = {
      background-color = mkLiteral "inherit";
      text-color = mkLiteral "inherit";
    };
  };
in
{
  imports = [
    ./waybar-config.nix
    ./theme-style.nix
    #./rofi-theme.nix
  ];

  nixpkgs = {
    overlays = [
      outputs.overlays.unstable-packages
      outputs.overlays.mod-packages
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  programs = {
    swaylock = {
      enable = true;
    };

    rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
      cycle = true;
      location = "center";
      theme = rofi-theme;
      #plugins = (
      #  with pkgs;
      #  [
      #    mod.rofi-calc-wayland
      #    mod.rofi-emoji-wayland
      #  ]
      #);
      xoffset = 0;
      yoffset = -20;
      extraConfig = {
        show-icons = true;
        kb-cancel = "Escape,Super+space";
        modi = "combi,window,run";
        # TODO: Fix calc for 24.11
        #modi = "combi,window,run,calc"; 
        #modi = "window,run,ssh,emoji,calc,systemd";
        sort = true;
        # levenshtein-sort = true;
      };
    };
  };

  # All Wayland/Hyprland dependent packages
  home.packages = with pkgs; [
    wdisplays # Graphical display layout for wayland
    wl-clipboard # Wayland clipboard
    cliphist # Clipboard manager for wayland with text and image support
    grim # Screecap
    slurp # Compositor screen selection tool
    wev # Wayland environment diagnostics
    swww # Wallpaper switcher
  ];

  xdg = {
    enable = true;
    portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      xdgOpenUsePortal = true;
      config = {
        common = {
          default = [ "gtk" ];
        };
      };
    };

    userDirs =
      let
        appendToHomeDir = path: "${config.home.homeDirectory}/${path}";
      in
      {
        enable = true;
        documents = appendToHomeDir "documents";
        download = appendToHomeDir "downloads";
        music = appendToHomeDir "music";
        pictures = appendToHomeDir "pictures";
        publicShare = appendToHomeDir "public";
        templates = appendToHomeDir "templates";
        videos = appendToHomeDir "videos";
        extraConfig = {
          XDG_PROJECT_DIR = appendToHomeDir "projects";
        };
      };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;

    settings = {
      # Mitigate Xwayland pixelation scaling issues
      xwayland = {
        force_zero_scaling = true;
      };

      exec-once = [
        "wl-paste --type text --watch cliphist store" # Store clipboard text
        "wl-paste --type image --watch cliphist store" # Store clipboard images
        "waybar"
        "swww init"
        "wallpaper-set"
      ];

      gestures = {
        workspace_swipe = true;
        workspace_swipe_forever = true;
      };

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
        "WLR_DRM_DEVICES,/var/run/egpu:/dev/dri/card0:/dev/dri/card1"
      ];

      # Fix for steam menus
      "windowrulev2" = [
        "stayfocused, title:^()$,class:^(steam)$"
        "minsize 1 1, title:^()$,class:^(steam)$"
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

      dwindle = {
        # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true; # you probably want this
      };

      master = {
        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        new_status = "master";
      };

      misc = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
      };

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#executing for more

      # Example windowrule v1
      # windowrule = float, ^(kitty)$
      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      "$mainMod" = "SUPER";

      # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      bind = [
        "$mainMod, Q, exec, alacritty"
        "$mainMod, return, exec, alacritty"
        "$mainMod SHIFT, w, exec, wallpaper-cycle"
        "$mainMod, C, killactive"
        "$mainMod, M, exit"
        #"$mainMod, E, exec, dolphin"
        "$mainMod, R, exec, rofi -show-icons -combi-modi drun,run -show combi"
        "$mainMod, P, pseudo, # dwindle"
        "$mainMod, V, togglesplit, # dwindle"
        "$mainMod, W, exec, pkill -SIGUSR1 waybar" # Toggle waybar visibility
        "$mainMod, D, focuswindow, title:^(Nuc)$" # Focus on NUC RDP window

        # Move focus with mainMod + arrow keys
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # Move focus with mainMod + vim keys
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"

        # Move window with mainMod + vim keys
        "$mainMod SHIFT, h, movewindow, l"
        "$mainMod SHIFT, l, movewindow, r"
        "$mainMod SHIFT, k, movewindow, u"
        "$mainMod SHIFT, j, movewindow, d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Toggle fullscreen
        "$mainMod, F, fullscreen, 1"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
