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

  cfg = config.services.batteryMinder;

  batteryMinder =
    pkgs.writeShellScriptBin "battery-notifier" # sh
      ''
        		#!/usr/bin/env bash

        		FIRST_WARN_PERCENT=${toString cfg.first_warn_percent}
        		FIRST_WARN_MSG=${escapeShellArg cfg.first_warn_msg}
        		WARN_BELOW=${toString cfg.warn_below}
        		WARN_BELOW_MSG=${escapeShellArg cfg.warn_below_msg}
        		SUSPEND_PERCENT=${toString cfg.suspend_percent}
        		SUSPEND_MSG=${escapeShellArg cfg.suspend_msg}
        		HIBERNATE_PERCENT=${toString cfg.hibernate_percent}
        		HIBERNATE_MSG=${escapeShellArg cfg.hibernate_msg}
        		SHUTDOWN_PERCENT=${toString cfg.shutdown_percent}
        		SHUTDOWN_MSG=${escapeShellArg cfg.shutdown_msg}

        		STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}"
        		STATE_FILE="''${STATE_DIR}/battery_notifier_last"
        		mkdir -p "''${STATE_DIR}"

        		BATTERY_PATH=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT' | head -n1)
        		[ -z "''${BATTERY_PATH}" ] && exit 0

        		STATUS=$(cat "''${BATTERY_PATH}/status" 2>/dev/null || echo "Unknown")
        		CAPACITY=$(cat "''${BATTERY_PATH}/capacity" 2>/dev/null || echo 100)

        		if ["''${STATUS}" != "Discharging" ]; then
        			echo 101 > "''${STATE_FILE}"
        			exit 0
        		fi

        		# Load last seen percentage (101 = "not seen discharging")
        		LAST=101
        		if [ -f "''${STATE_FILE}" ]; then
        			read -r LAST < "''${SATE_FILE}" || LAST=101
        		fi

        		update_last() {
        			echo "''${CAPACITY}" > "''${STATE_FILE}"
        		}

        		# Check in reverse order from shutdown to hibernate to suspend to warn
        		if [ "''${SHUTDOWN_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" ] -le "''${SHUTDOWN_PERCENT}" ] && [ "''${LAST}" -gt "''${SHUTDOWN_PERCENT}" ]; then
        			${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${SHUTDOWN_MSG}" 
        			update_last
        			systemctl poweroff
        			exit 0
        		fi

        		if [ "''${HIBERNATE_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" ] -le "''${HIBERNATE_PERCENT}" ] && [ "''${LAST}" -gt "''${HIBERNATE_PERCENT}" ]; then
        			${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${HIBERNATE_MSG}" 
        			update_last
        			systemctl hibernate
        			exit 0
        		fi

        		if [ "''${SUSPEND_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" ] -le "''${SUSPEND_PERCENT}" ] && [ "''${LAST}" -gt "''${SUSPEND_PERCENT}" ]; then
        			${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${SUSPEND_MSG}" 
        			update_last
        			systemctl suspend
        			exit 0
        		fi

        		if [ "''${FIRST_WARN_PERCENT}" -gt 0 ] && [ "''${CAPACITY}" ] -le "''${FIRST_WARN_PERCENT}" ] && [ "''${LAST}" -gt "''${FIRST_WARN_PERCENT}" ]; then
        			${pkgs.libnotify}/bin/notify-send -u normal "Battery ''${CAPACITY}%" "''${FIRST_WARN_MSG}" 
        			update_last
        			exit 0
        		fi

        		if [ "''${WARN_BELOW}" -gt 0 ] && [ "''${CAPACITY}" -lt "''${WARN_BELOW}" ] && "''${CAPACITY}" -lt "''${LAST}" ]; then
        			${pkgs.libnotify}/bin/notify-send -u critical "Battery ''${CAPACITY}%" "''${WARN_MSG}" 
        			update_last
        			exit 0
        		fi
        	'';
in
{
  options.services.batteryMinder = {
		enable = mkEnableOption "Battery monitering service with warning + suspend/hibernate/shutdown actions";

    first_warn_percent = mkOption {
      type = types.int;
      default = 20;
      description = ''
        			Battery percentage at or below which the first warning is given.
        			Set to 0 to disable.
        		'';
    };

    first_warn_msg = mkOption {
      type = types.str;
      default = "🪫⚠️Battery is low.";
      description = "First warning message to show for a low battery.";
    };

    warn_below_percent = mkOption {
      type = types.int;
      default = 10;
      description = ''
        			Battery percentage at or below continuos warnings are given.
        			Set to 0 to disable repeat warnings.
        		'';
    };

    warn_msg = mkOption {
      type = types.str;
      default = "🪫‼️Battery is running critically low!";
      description = "Notification message for repeated battery warnings below the warn_below level.";
    };

    suspend_percent = mkOption {
      type = types.int;
      default = 4;
      description = ''
        			Battery percentage at or below which the system will suspend.
        			Triggers once per discharge cycle when crossing this threshold.
        			Set to 0 to disable suspend.
        		'';
    };

    suspend_msg = mkOption {
      type = types.str;
      default = "🪫‼️Battery critically low. Suspending system...";
      description = "Notification shown when suspending system.";
    };

    hibernate_percent = mkOption {
      type = types.int;
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
      default = "🪫‼️Battery critically low. Hibernating system...";
      description = "Notification shown when hibernating system.";
    };

    shutdown_percent = mkOption {
      type = types.int;
      default = 1;
      description = ''
        			Battery percentage at which the system will shutdown.
        			Triggers once per discharge cycle when crossing this threshold.
        			Set to 0 to disable shutdown.
        		'';
    };

    shutdown_msg = mkOption {
      type = types.str;
      default = "🪫‼️Battery critically low. Shutting down...";
      description = "Notification shown when shutting down the system.";
    };

    batteryInterval = mkOption {
      type = types.int;
      default = 60;
      description = "How often (in seconds) to check the battery status.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      batteryMinder
      pkgs.libnotify
    ];

    systemd.user.services."battery-minder" = {
      Unit = {
        Description = "Battery level warning notifications and actions";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${batteryMinder}/bin/battery-minder";
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
      install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
