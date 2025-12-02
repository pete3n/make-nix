{
  lib,
  config,
  ...
}: {
  options = {
    services.backup = {
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
        default = [];
        description = "List of patterns to backup";
      };
    };
  };

  config = lib.mkIf config.services.backup.enable {
    services.borgmatic = {
      enable = true;

      inherit (config.services.backup) frequency;
    };

    programs.borgmatic = {
      enable = true;

      backups = {
        local = lib.mkIf (config.services.backup.local.destination != "") {
          location = {
            repositories = [config.services.backup.local.destination];
            inherit (config.services.backup) patterns;
          };

          retention = {
            keepDaily = 60;
            keepWeekly = 52;
            keepMonthly = 36;
            keepYearly = 20;
          };
        };

        remote = lib.mkIf (config.services.backup.remote.ssh_name != "") {
          location = {
            repositories = ["ssh://${config.services.backup.remote.ssh_name}/./Borg"];
            inherit (config.services.backup) patterns;
          };

          storage.encryptionPasscommand = "cat ${config.services.backup.remote.password_path}";

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
