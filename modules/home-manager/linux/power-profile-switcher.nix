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
    ;

  cfg = config.services."power-profile-switcher";

  # upower is a system service dependency
  hasUpower = config ? services && config.services ? upower && config.services.upower ? enable;
  upowerEnabled = hasUpower && config.services.upower.enable;

  hasPowerProfilesDaemon =
    config ? services
    && config.services ? "power-profiles-daemon"
    && config.services."power-profiles-daemon" ? enable;
  powerProfilesDaemonEnabled =
    hasPowerProfilesDaemon && config.services."power-profiles-daemon".enable;

  power-profile-switcher =
    pkgs.writeShellScriptBin "power-profile-switcher" # sh
      ''
				#!/usr/bin/env bash
				
				ON_BATTERY_BRIGHTNESS=${toString cfg.on_battery_brightness}
				ON_AC_BRIGHTNESS=${toString cfg.on_ac_brightness}
				ON_BATTERY_PROFILE=${toString cfg.on_battery_profile}
				ON_AC_PROFILE=${toString cfg.on_ac_profile}
				
				BATTERY=$(${pkgs.upower}/bin/upower -e | grep -m1 'BAT')
				[ -z "''${BATTERY}" ] && exit 0
				
				get_state() {
					${pkgs.upower}/bin/upower -i "''${BATTERY}" | ${pkgs.gawk}/bin/awk '/state:/ {print $2; exit}'
				}
				
				get_brightness_percent() {
					local cur max
					cur=$(${pkgs.brightnessctl}/bin/brightnessctl g)
					max=$(${pkgs.brightnessctl}/bin/brightnessctl m)
					printf "%s\n" $(( cur * 100 / max ))
				}

				discharging_actions() {
					local cur_percent
					cur_percent=$(get_brightness_percent)
					if [ "$cur_percent" -gt "''${ON_BATTERY_BRIGHTNESS}" ]; then 
						${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "''${ON_BATTERY_PROFILE}"
						${pkgs.brightnessctl}/bin/brightnessctl s "''${ON_BATTERY_BRIGHTNESS}%"
					fi
				}
			
				charging_actions() {
					${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "''${ON_AC_PROFILE}"
					${pkgs.brightnessctl}/bin/brightnessctl s "''${ON_AC_BRIGHTNESS}%"
				}
				
				current_state=$(get_state)
				
				if [ "$current_state" = "discharging" ]; then
					discharging_actions
				elif [ "$current_state" = "charging" ]; then
					charging_actions
				fi
				
				${pkgs.upower}/bin/upower --monitor-detail | while read -r line; do
					case "$line" in
						*"state:"*)
							new_state=$(${pkgs.gawk}/bin/awk '{print $2}' <<< "$line")
							[ "$new_state" = "$current_state" ] && continue
							current_state="$new_state"
				
							if [ "$new_state" = "discharging" ]; then
								discharging_actions
							elif [ "$new_state" = "charging" ]; then
								charging_actions
							fi
						;;
					esac
				done
      '';
in
{
  options.services."power-profile-switcher" = {
    enable = mkEnableOption "Auto power profile switcher and charge/discharge actions";

    on_battery_profile = mkOption {
      type = types.enum [
        "power-saver"
        "balanced"
        "performance"
      ];
      default = "power-saver";
      description = ''
        				Powerprofile to switch to when on battery.
        				One of: "power-saver", "balanced", or "performance"
        			'';
    };

    on_ac_profile = mkOption {
      type = types.enum [
        "power-saver"
        "balanced"
        "performance"
      ];
      default = "performance";
      description = ''
        				Powerprofile to switch to when on AC power.
        				One of: "power-saver", "balanced", or "performance" 
        			'';
    };

    on_battery_brightness = mkOption {
      type = types.ints.between 0 100;
      default = 50;
      description = ''
        				Brightness to switch to when on battery.
        				Range: 0 - 100
        			'';
    };

    on_ac_brightness = mkOption {
      type = types.ints.between 0 100;
      default = 100;
      description = ''
        				Brightness to switch to when on AC power.
        				Range: 0 - 100
        			'';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (!hasUpower) || upowerEnabled;
        message = ''
          							power-profile-switcher required the upower system service to be enabled.

          							Add:
          								services.upower.enable = true;

          							To your system configuration and rebuild the configuration.
          						'';
      }
      {
        assertion = (!hasPowerProfilesDaemon) || powerProfilesDaemonEnabled;
        message = ''
          							power-profile-switcher required the power-profiles-daemon system service to be enabled.

          							Add:
          								services.power-profiles-daemon.enable = true;

          							To your system configuration and rebuild the configuration.
          						'';
      }
    ];

    home.packages = [
      power-profile-switcher
      pkgs.upower
      pkgs.power-profiles-daemon
      pkgs.brightnessctl
    ];

    systemd.user.services."power-profile-switcher" = {
      Unit = {
        Description = "Auto-switch power-profile and perform actions on charging/discharging";
        # Stop the service when we are heading toward sleep
        Conflicts = [ "sleep.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${power-profile-switcher}/bin/power-profile-switcher";
        Restart = "always";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

}
