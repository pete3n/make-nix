{
  lib,
  config,
  pkgs,
  makeNixLib,
  makeNixAttrs,
  ...
}:
let
  cfg = config.services.backup;
  isLinux = makeNixLib.isLinux makeNixAttrs.system;
  isDarwin = makeNixLib.isDarwin makeNixAttrs.system;
in
{
  options.services.backup = {
    enable = lib.mkEnableOption "enable automatic backups";
    local.destination = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The destination directory to backup to";
    };
    remote = {
      password_path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The password to encrypt the remote backup with";
      };
      ssh_name = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The name of the ssh connection to connect to the remote destination with";
      };
    };
    frequency = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "OnCalendar schedule for the backup (e.g. 'daily', 'weekly', 'Mon *-*-* 12:00:00')";
    };
    patterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of patterns to backup";
    };
  };

  config = lib.mkIf cfg.enable {
    # Scheduling: systemd on Linux, launchd on macOS
    services.borgmatic = lib.mkIf isLinux {
      enable = true;
      inherit (cfg) frequency;
    };

    launchd.agents.borgmatic = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.borgmatic}/bin/borgmatic" ];
        StartCalendarInterval = [
          {
            Hour = 0;
            Minute = 0;
          }
        ];
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/borgmatic.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/borgmatic.log";
      };
    };

    programs.borgmatic = {
      enable = true;
      backups = {
        local = lib.mkIf (cfg.local.destination != "") {
          location = {
            repositories = [ cfg.local.destination ];
            inherit (cfg) patterns;
          };
          retention = {
            keepDaily = 60;
            keepWeekly = 52;
            keepMonthly = 36;
            keepYearly = 20;
          };
        };
        remote = lib.mkIf (cfg.remote.ssh_name != "") {
          location = {
            repositories = [ "ssh://${cfg.remote.ssh_name}/./Borg" ];
            inherit (cfg) patterns;
          };
          storage.encryptionPasscommand = "cat ${cfg.remote.password_path}";
          retention = {
            keepDaily = 60;
            keepWeekly = 52;
            keepMonthly = 36;
            keepYearly = 20;
          };
        };
      };
    };
  };
}
