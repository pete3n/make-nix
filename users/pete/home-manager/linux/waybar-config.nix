{
	config,
  lib,
  pkgs,
  ...
}:
let
  waybarScripts = import ./waybar-scripts.nix { inherit pkgs; };
in
{
  home.packages = with pkgs; [
    fuzzel
    hyprsysteminfo
    pavucontrol
  ];

  programs = {
    khal = {
      enable = true;
    };

    pomodoro = {
      enable = true;
			activityIntervals = [ 1 10 15 25 50 75 ];
			restIntervals = [ 1 5 10 15 ];
			activityPlaylist = "focus";
			restPlaylist = "chill";
			activityImage = "${config.xdg.userDirs.pictures}/pomodoro/focus/";
			restImage = "${config.xdg.userDirs.pictures}/pomodoro/chill/";
			imageDisplayDuration = 10;
			defaultActivityName = "Focus";
    };

    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          start_hidden = true;
          height = 30;
          margin-left = 15;
          margin-right = 15;

          modules-left = [
            "custom/snowflake"
            "hyprland/workspaces"
          ];

          modules-center = [ "custom/clock" ];

          modules-right = [
            "custom/mpd_prev"
            "custom/playerctl"
            "custom/mpd_next"
            "custom/mpd_shuffle"
            "custom/mpd_repeat_cycle"
            "pulseaudio"
            "backlight"
            "custom/wdisplays"
            "battery"
          ];

          "custom/snowflake" = {
            exec = "${waybarScripts.nixVersions}/bin/get-nix-versions";
            format = "❄️";
            return-type = "json";
            tooltip = false;
            on-click = "${pkgs.libnotify}/bin/notify-send 'Nix Info' \"$(${waybarScripts.nixVersions}/bin/get-nix-versions | ${pkgs.jq}/bin/jq -r '.tooltip')\"";
            on-click-right = "${pkgs.hyprsysteminfo}/bin/hyprsysteminfo";
          };

          "hyprland/workspaces" = {
            format = "{name} {icon}";
            tooltip = false;
            all-outputs = true;
            format-icons = {
              "active" = " ";
              "default" = " ";
            };
          };

          "custom/clock" = {
            format = "{}";
            return-type = "json";
            interval = 1;
						restart-interval = 1;
            exec = "pomodoro ticker";
            on-click = "pomodoro-config";
            on-click-right = lib.getExe waybarScripts.calendarToggle;
          };

          "custom/mpd_prev" = {
            format = "⏮";
            tooltip-format = "Previous Track";
            on-click = "playerctl -p mpd previous";
          };

          "custom/playerctl" = {
            format = "<span>{}</span>";
            return-type = "json";
            tooltip = true;
            max-length = 35;
            interval = 1;
            exec = lib.getExe waybarScripts.mpdWaybarTicker;

            on-click = "playerctl -p mpd play-pause";
            on-click-right = lib.getExe waybarScripts.mpdPopout;
            on-click-middle = lib.getExe waybarScripts.mpdVizArtPopout;
            on-scroll-up = "playerctl -p mpd next";
            on-scroll-down = "playerctl -p mpd previous";
          };

          "custom/mpd_next" = {
            format = "⏭";
            tooltip-format = "Next Track";
            on-click = "playerctl -p mpd next";
          };

          "custom/mpd_shuffle" = {
            return-type = "json";
            exec = lib.getExe waybarScripts.mpdShuffleWaybar;
            interval = 1;
            on-click = "${pkgs.mpc}/bin/mpc random";
          };

          "custom/mpd_repeat_cycle" = {
            return-type = "json";
            exec = lib.getExe waybarScripts.mpdRepeatCycle;
            interval = 1;
            on-click = lib.getExe waybarScripts.mpdRepeatCycleClick;
          };

          "pulseaudio" = {
            format = "{icon} {volume}%";
            format-muted = "󰝟 ";
            tooltip = true;
            format-icons = {
              headphone = "󰋋 ";
              default = [
                "󰕿 "
                "󰖀 "
                "󰕾 "
              ];
            };
            scroll-step = 1;
            on-click = "pavucontrol";
            on-click-right = "easyeffects";
          };

          "backlight" = {
            device = "intel_backlight";
            format = "{icon} {percent}%";
            tooltip-format = "Brightness: {percent}%";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
            scroll-step = 1;
          };

          "custom/wdisplays" = {
            format = "󰹑";
            tooltip = true;
            tooltip-format = "Display Settings";
            on-click = "wdisplays";
          };

          "battery" = {
            states = {
              good = 95;
              warning = 30;
              critical = 15;
            };
            format = "{icon}  {capacity}%";
            format-charging = " ⚡{capacity}%";
            format-alt = "{time} {icon}";
            format-icons = [
              " "
              " "
              " "
              " "
              " "
            ];
          };
        };
      };

      style = # css
        ''
                    /* Global defaults */
                    * {
                      border: none;
                      border-radius: 0;
                      font-size: 14px;
                      min-height: 25px;
                    }

                    window#waybar {
                      background: transparent;
                    }

                    /* Uniform hover + smooth transition */
                    #waybar button,
                    #waybar label,
                    #waybar box {
                      transition: background-color 0.15s ease;
                    }

                    #waybar button:hover,
                    #waybar label:hover,
                    #waybar box:hover {
                      background-color: rgba(82, 119, 195, 0.15);
                    }

                    /* --- Your existing module styling (kept close to what you had) --- */

                    #custom-snowflake {
                      font-size: 20px;
                      background: transparent;
                      color: #5277c3;
                      border-radius: 5px;
                      padding-left: 10px;
                    }

                    /* Now playing */
                    #custom-playerctl {
                      background: transparent;
                      color: #5277c3;
                      padding-left: 10px;
                      padding-right: 10px;
                      border-radius: 6px; /* makes hover look nicer */
                    }
                    #custom-playerctl.Playing { opacity: 1.0; }
                    #custom-playerctl.Paused  { opacity: 0.7; }
                    #custom-playerctl.Stopped { opacity: 0.4; }

                    /* MPD control buttons */
                    #custom-mpd_prev,
                    #custom-mpd_next,
                    #custom-mpd_shuffle,
                    #custom-mpd_repeat_cycle {
                      background: transparent;
                      color: #5277c3;
                      padding: 0 8px;
                      margin: 0 2px;
                      border-radius: 6px;
                    }

                    /* Repeat-cycle state styling */
                    #custom-mpd_repeat_cycle.off      { opacity: 0.45; }
                    #custom-mpd_repeat_cycle.playlist { opacity: 1.0; }
                    #custom-mpd_repeat_cycle.track    { opacity: 1.0; text-shadow: 0 0 6px rgba(126, 186, 228, 0.55); }

                    /* Shuffle state styling */
                    #custom-mpd_shuffle.off { opacity: 0.45; }
                    #custom-mpd_shuffle.on  { opacity: 1.0; text-shadow: 0 0 6px rgba(126, 186, 228, 0.55); }

                    /* Workspaces */
                    #hyprland-workspaces {
                      background: transparent;
                      color: #5277c3;
                      padding-right: 10px;
                    }
                    #workspaces button {
                      background: transparent;
                      color: #5277c3;
                      padding: 0 5px;
                    }

                    /* Clock */
                    #clock {
                      background: transparent;
                      color: #7ebae4;
                      border-radius: 6px;
                      padding: 0 10px;
                    }

          					/* Custom-clock */
          					#custom-clock {
          						background: transparent;
          						padding: 0 10px;
          						border-radius: 6px;
          					}
          					#custom-clock.clock   { color: #7ebae4; }
          					#custom-clock.activity { color: #5277c3; }
          					#custom-clock.rest    { color: #7ebae4; }

                    /* Displays launcher */
                    #custom-wdisplays {
                      background: transparent;
                      color: #5277c3;
                      padding-top: 3px;
                      padding-left: 15px;
                      padding-right: 10px;
                      border-radius: 6px;
                    }

                    /* Backlight */
                    #backlight {
                      background: transparent;
                      color: #5277c3;
                      padding-top: 2px;
                      padding-bottom: 2px;
                      padding-left: 10px;
                      padding-right: 10px;
                      border-radius: 6px;
                    }

                    /* Audio */
                    #pulseaudio {
                      background: transparent;
                      color: #5277c3;
                      padding-left: 10px;
                      padding-right: 10px;
                      border-radius: 6px;
                    }

                    /* Battery */
                    #battery {
                      background: transparent;
                      color: #5277c3;
                      padding-left: 10px;
                      padding-right: 10px;
                      border-radius: 6px;
                    }
        '';
    };
  };
}
