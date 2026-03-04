# Khal calendar notification service
# Polls upcoming events and fires dunst notifications at configured offsets
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.khalNotify;

  khalNotify =
    pkgs.writeShellScriptBin "khal-notify" # bash
      ''
        set -u

        NIX_NOTIFY="${pkgs.libnotify}/bin/notify-send"
        NIX_DATE="${pkgs.coreutils}/bin/date"
        NIX_FIND="${pkgs.coreutils}/bin/find"
        NIX_SQLITE="${pkgs.sqlite}/bin/sqlite3"
        NIX_GREP="${pkgs.gnugrep}/bin/grep"
        NIX_SED="${pkgs.gnused}/bin/sed"

        KHAL_DB="''${HOME}/.local/share/khal/khal.db"
        KHAL_TZ="America/New_York"
        NOTIFY_TIME=${toString cfg.notifyTime}

        state_dir="''${XDG_STATE_HOME:-''${HOME}/.local/state}/khal-notify"
        mkdir -p "''${state_dir}"

        now_epoch="$("''${NIX_DATE}" +%s)"
        _event_tmp="''${state_dir}/current_event.tmp"

        # Cleanup state files older than 25 hours
        # Exclude the temp file from cleanup
        "''${NIX_FIND}" "''${state_dir}" -maxdepth 1 -type f -mmin +1500 \
        ! -name 'current_event.tmp' -delete 2>/dev/null || true

        # Parse ISO 8601 duration to minutes
        # Handles -PT10M (minutes), -PT1H (hours), -P1D (days), and combinations
        parse_trigger_minutes() {
        	_trigger="''${1}"
        	_days=0
        	_hours=0
        	_mins=0

        	# Strip carriage returns, leading - and P
        	_tstrip="$(printf '%s' "''${_trigger}" | tr -d '\r' | "''${NIX_SED}" 's/^-*P//')"

        	# Match days: 1D
        	_day_val="$(printf '%s' "''${_tstrip}" | "''${NIX_SED}" -n 's/^\([0-9]*\)D.*/\1/p')"
        	[ -n "''${_day_val}" ] && _days="''${_day_val}"

        	# Match hours: T1H
        	_hour_val="$(printf '%s' "''${_tstrip}" | "''${NIX_SED}" -n 's/.*T\([0-9]*\)H.*/\1/p')"
        	[ -n "''${_hour_val}" ] && _hours="''${_hour_val}"

        	# Match minutes: T1H10M (with preceding hours) or T10M (minutes only)
        	_min_val="$(printf '%s' "''${_tstrip}" | "''${NIX_SED}" -n 's/.*T[0-9]*H\([0-9]*\)M/\1/p')"
        	if [ -z "''${_min_val}" ]; then
        	_min_val="$(printf '%s' "''${_tstrip}" | "''${NIX_SED}" -n 's/.*T\([0-9]*\)M/\1/p')"
        	fi
        	[ -n "''${_min_val}" ] && _mins="''${_min_val}"

        	printf '%s' "$(( (_days * 1440) + (_hours * 60) + _mins ))"
        }

        # Process a single event from temp file
        process_event() {
        	_file="''${1}"

        	_uid="$("''${NIX_GREP}" '^UID:' "''${_file}" | "''${NIX_SED}" 's/^UID://')"
        	_summary="$("''${NIX_GREP}" '^SUMMARY:' "''${_file}" | "''${NIX_SED}" 's/^SUMMARY://')"
        	_dtstart="$("''${NIX_GREP}" '^DTSTART' "''${_file}" \
        	| "''${NIX_SED}" 's/.*:\([0-9]*T[0-9]*\).*/\1/')"

        	[ -n "''${_uid:-}" ]     || return 0
        	[ -n "''${_summary:-}" ] || return 0
        	[ -n "''${_dtstart:-}" ] || return 0

        	# Reformat DTSTART: 20260303T211500 -> 2026-03-03 21:15:00
        	_date_part="''${_dtstart%T*}"
        	_time_part="''${_dtstart#*T}"
        	_start_fmt="''${_date_part:0:4}-''${_date_part:4:2}-''${_date_part:6:2} ''${_time_part:0:2}:''${_time_part:2:2}:''${_time_part:4:2}"
        	_start_epoch="$(
        		TZ="''${KHAL_TZ}" "''${NIX_DATE}" -d "''${_start_fmt}" +%s 2>/dev/null
        	)" || return 0

        	# Only process future events within 25 hours
        	_lookahead=$(( now_epoch + 90000 ))
        	[ "''${_start_epoch}" -gt "''${now_epoch}" ] || return 0
        	[ "''${_start_epoch}" -le "''${_lookahead}" ] || return 0

        	# Get per-event alarm triggers if any, parse to minutes
        	_triggers="$(
        		"''${NIX_GREP}" '^TRIGGER:' "''${_file}" | "''${NIX_SED}" 's/^TRIGGER://'
        	)"

        	# Build list of offsets: use per-event triggers if present,
        	# otherwise fall back to global offsets
        	if [ -n "''${_triggers:-}" ]; then
        		_offsets="$(
        			printf '%s\n' "''${_triggers}" \
        		| while IFS= read -r _trigger; do
        				[ -n "''${_trigger:-}" ] || continue
        				_mins="$(parse_trigger_minutes "''${_trigger}")"
        				[ "''${_mins}" -gt 0 ] || continue
        				printf '%s ' "''${_mins}"
        			done
        		)"
        	else
        		# Fall back to global offsets injected at build time
        		_offsets="${lib.concatStringsSep " " (map toString cfg.reminderOffsets)}"
        	fi

        	for _offset in ''${_offsets}; do
        		_target_epoch=$(( _start_epoch - (_offset * 60) ))
        		_delta=$(( now_epoch - _target_epoch ))
        		[ "''${_delta}" -lt 0 ] && _delta=$(( -_delta ))
        		[ "''${_delta}" -le 60 ] || continue

        		_state_file="''${state_dir}/''${_uid}-''${_offset}"
        		[ -f "''${_state_file}" ] && continue

        		"''${NIX_NOTIFY}" -t "''${NOTIFY_TIME}"\
        		--app-name="khal" \
        		--urgency=normal \
        		"''${_summary}" \
        		"Starting in ''${_offset} minute(s) at ''${_start_fmt}" \
        		|| true

        		printf '%s\n' "''${_uid}" > "''${_state_file}"
        	done
        }

        # Read all event blobs from sqlite
        # Write each VEVENT block to a temp file and process it
        _in_vevent=0

        while IFS= read -r _line; do
        	case "''${_line}" in
        		BEGIN:VEVENT*)
        			: > "''${_event_tmp}"
        			_in_vevent=1
        			;;
        		END:VEVENT*)
        			_in_vevent=0
        			process_event "''${_event_tmp}"
        			: > "''${_event_tmp}"
        			;;
        		*)
        			if [ "''${_in_vevent}" = "1" ]; then
        				printf '%s\n' "''${_line}" >> "''${_event_tmp}"
        			fi
        			;;
        	esac
        done < <("''${NIX_SQLITE}" "''${KHAL_DB}" "SELECT item FROM events;" | tr -d '\r')

        rm -f "''${_event_tmp}" 2>/dev/null || true
      '';
in
{
  options.services.khalNotify = {
    enable = lib.mkEnableOption "khal calendar notification service";

    calendarDir = lib.mkOption {
      type = lib.types.str;
      default = "%h/.local/share/khal/calendars/default";
      example = "%h/.local/share/khal/calendars/default";
      description = ''
        Path to the khal calendar directory.
        %h is expanded to $HOME by khal.
        Default: %h/.local/share/khal/calendars/default
      '';
    };

    reminderOffsets = lib.mkOption {
      type = lib.types.listOf lib.types.ints.unsigned;
      default = [
        15
        5
        1
      ];
      example = [
        30
        15
        5
        1
      ];
      description = ''
        List of reminder times in minutes before each event start.
        A notification will be sent at each offset.
        Default: [ 15 5 1 ]
      '';
    };

    notifyTime = lib.mkOption {
      type = lib.types.ints.between 1000 60000;
      default = 15000;
      description = ''
        Time to display event notification in ms.
        Range: 1000 - 60000
        Default: 15000
      '';
    };

    timerIntervalSec = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 15;
      example = 60;
      description = ''
        How often the notification service runs in seconds.
        Should be 60 or less to reliably catch the 1-minute offset window.
        Default: 15
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ khalNotify ];

    systemd.user.services."khal-notify" = {
      Unit = {
        Description = "khal calendar notification service";
        After = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${khalNotify}/bin/khal-notify";
      };
    };

    systemd.user.timers."khal-notify" = {
      Unit = {
        Description = "khal calendar notification timer";
      };
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "${toString cfg.timerIntervalSec}s";
        Unit = "khal-notify.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
