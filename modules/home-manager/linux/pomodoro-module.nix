{ config, lib, pkgs, ... }:
let
  cfg = config.programs.pomodoro;
in
{
  options.programs.pomodoro = {
    enable = lib.mkEnableOption "Pomodoro timer";

    activityIntervals = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 25 50 75 ];
      description = "Activity interval options in minutes";
    };

    restIntervals = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 5 10 15 ];
      description = "Rest interval options in minutes";
    };

    activityPlaylist = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "MPD playlist name for activity phase";
    };

    restPlaylist = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "MPD playlist name for rest phase";
    };

    activityImage = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to activity image or directory";
    };

    restImage = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to rest image or directory";
    };

    imageDisplayDuration = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds to display transition image";
    };

    defaultActivityName = lib.mkOption {
      type = lib.types.str;
      default = "Activity";
      description = "Default activity name if none configured";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.local.pomodoro-timer ];

    xdg.configFile."pomodoro/config.json".text = builtins.toJSON {
      activity_intervals    = cfg.activityIntervals;
      rest_intervals        = cfg.restIntervals;
      activity_playlist     = cfg.activityPlaylist;
      rest_playlist         = cfg.restPlaylist;
      activity_image        = cfg.activityImage;
      rest_image            = cfg.restImage;
      image_display_duration = cfg.imageDisplayDuration;
      default_activity_name = cfg.defaultActivityName;
    };
  };
}
