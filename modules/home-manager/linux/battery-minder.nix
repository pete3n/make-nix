{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    escapeShellArg
    ;

  cfg = config.services.battery-minder;

  battery-minder =
    pkgs.writeShellScriptBin "battery-minder" # sh
      ''
        #!/usr/bin/env bash

				WARN_FIRST_PERCENT=${toString cfg.warn_first_percent}
				WARN_FIRST_MSG=${escapeShellArg cfg.warn_first_msg}
				WARN_BELOW_PERCENT=${toString cfg.warn_below_percent}
				WARN_BELOW_MSG=${escapeShellArg cfg.warn_below_msg}
				SUSPEND_PERCENT=${toString cfg.suspend_percent}
				SUSPEND_MSG=${escapeShellArg cfg.suspend_msg}
				HIBERNATE_PERCENT=${toString cfg.hibernate_percent}
				HIBERNATE_MSG=${escapeShellArg cfg.hibernate_msg}
				SHUTDOWN_PERCENT=${toString cfg.shutdown_percent}
				SHUTDOWN_MSG=${escapeShellArg cfg.shutdown_msg}

				STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/battery-minder"
				STATE_FILE="''${STATE_DIR}/last_capacity"
				mkdir -p "''${STATE_DIR}"

				BATTERY_PATH=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' | head -n1)
				[ -z "''${BATTERY_PATH}" ] && exit 0

				STATUS=$(cat "''${BATTERY_PATH}/status" || echo "Unknown")
				CAPACITY=$(cat "''${BATTERY_PATH}/capacity" || echo 100)

				if [ "''${STATUS}" = "Charging" ] || [ "''${STATUS}" = "Full" ]; then
					echo 101 > "''${STATE_FILE}"
					exit 0
				else
					echo "''${CAPACITY}" > "''${STATE_FILE}"
					exit 0
				fi

				# Load last seen percentage (101 = "not seen discharging")
				LAST=101
				if [ -f "''${STATE_FILE}" ]; then
					read -r LAST < "''${STATE_FILE}" || LAST=101
				fi

				update_last() {
					echo "''${CAPACITY}" > "''${STATE_FILE}"
				}

				# Check in reverse order from shutdown to hibernate to suspend to warn
				if [ "''${SHUTDOWN_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" -le "''${SHUTDOWN_PERCENT}" ] && [ "''${LAST}" -gt "''${SHUTDOWN_PERCENT}" ]; then
					${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${SHUTDOWN_MSG}" 
					update_last
					systemctl poweroff
					exit 0
				fi

				if [ "''${HIBERNATE_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" -le "''${HIBERNATE_PERCENT}" ] && [ "''${LAST}" -gt "''${HIBERNATE_PERCENT}" ]; then
					${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${HIBERNATE_MSG}" 
					update_last
					systemctl hibernate
					exit 0
				fi

				if [ "''${SUSPEND_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" -le "''${SUSPEND_PERCENT}" ] && [ "''${LAST}" -gt "''${SUSPEND_PERCENT}" ]; then
					${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${SUSPEND_MSG}" 
					update_last
					systemctl suspend
					exit 0
				fi

				if [ "''${WARN_FIRST_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" -le "''${WARN_FIRST_PERCENT}" ] && [ "''${LAST}" -gt "''${WARN_FIRST_PERCENT}" ]; then
					${pkgs.libnotify}/bin/notify-send -u normal "Battery ''${CAPACITY}%" "''${WARN_FIRST_MSG}" 
					update_last
					exit 0
				fi

				if [ "''${WARN_BELOW_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" -lt "''${WARN_BELOW_PERCENT}" ] && [ "''${CAPACITY}" -lt "''${LAST}" ]; then
					${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${WARN_BELOW_MSG}" 
					update_last
					exit 0
				fi
      '';
in
{
  options.services.battery-minder = {
    enable = mkEnableOption "Battery monitering service with warning + suspend/hibernate/shutdown actions";

    warn_first_percent = mkOption {
      type = types.ints.between 0 100;
      default = 20;
      description = ''
        			Battery percentage at or below which the first warning is given.
        			Set to 0 to disable.
        		'';
    };

    warn_first_msg = mkOption {
      type = types.str;
      default = "🪫⚠️ Battery is low.";
      description = "First warning message to show for a low battery.";
    };

    warn_below_percent = mkOption {
      type = types.ints.between 0 100;
      default = 15;
      description = ''
        			Battery percentage at or below continuos warnings are given.
        			Set to 0 to disable repeat warnings.
        		'';
    };

    warn_below_msg = mkOption {
      type = types.str;
      default = "🪫‼️ Battery is running critically low!";
      description = "Notification message for repeated battery warnings below the warn_below level.";
    };

    suspend_percent = mkOption {
      type = types.ints.between 0 100;
      default = 10;
      description = ''
        			Battery percentage at or below which the system will suspend.
        			Triggers once per discharge cycle when crossing this threshold.
        			Set to 0 to disable suspend.
        		'';
    };

    suspend_msg = mkOption {
      type = types.str;
      default = "🪫‼️ Battery critically low. 🌙 Suspending system...";
      description = "Notification shown when suspending system.";
    };

    hibernate_percent = mkOption {
      type = types.ints.between 0 100;
      default = 0;
      description = ''
        			Battery percentage at or below which the system will hibernate.
        			Triggers once per discharge cycle when crossing this threshold.
        			Set to 0 to disable hibernate.
        			NOTE: You must have swap+resume correctly configured for this to function.
        		'';
    };

    hibernate_msg = mkOption {
      type = types.str;
      default = "🪫‼️ Battery critically low. ❄️Hibernating system...";
      description = "Notification shown when hibernating system.";
    };

    shutdown_percent = mkOption {
      type = types.ints.between 0 100;
      default = 1;
      description = ''
        			Battery percentage at which the system will shutdown.
        			Triggers once per discharge cycle when crossing this threshold.
        			Set to 0 to disable shutdown.
        		'';
    };

    shutdown_msg = mkOption {
      type = types.str;
      default = "🪫‼️ Battery critically low. ⏻ Shutting down...";
      description = "Notification shown when shutting down the system.";
    };

    batteryInterval = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "How often (in seconds) to check the battery status.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      battery-minder
      pkgs.libnotify
    ];

    systemd.user.services."battery-minder" = {
      Unit = {
        Description = "Battery level warning notifications and actions";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${battery-minder}/bin/battery-minder";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.timers."battery-minder" = {
      Unit = {
        Description = "Periodic battery level check";
      };
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "${toString cfg.batteryInterval}s";
        AccuracySec = "10s";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
