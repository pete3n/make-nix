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
    pkgs.writeShellScriptBin "khal-notify" # sh
      ''
        set -u

        NIX_KHAL="${pkgs.khal}/bin/khal"
        NIX_JQ="${pkgs.jq}/bin/jq"
        NIX_NOTIFY="${pkgs.libnotify}/bin/notify-send"
        NIX_DATE="${pkgs.coreutils}/bin/date"
        NIX_FIND="${pkgs.coreutils}/bin/find"

        KHAL_CALENDAR_DIR="${cfg.calendarDir}"
        KHAL_CONFIG="${config.xdg.configHome}/khal/config"
        TZ="America/New_York"

        state_dir="''${XDG_STATE_HOME:-''${HOME}/.local/state}/khal-notify"
        mkdir -p "''${state_dir}"

        now_epoch="$("''${NIX_DATE}" +%s)"

        # Cleanup state files for events that have already passed
        # State files are named <uid>-<offset>, mtime reflects when they were written
        # Remove any state file older than 25 hours
        "''${NIX_FIND}" "''${state_dir}" -maxdepth 1 -type f -mmin +1500 -delete 2>/dev/null || true

        # Query khal for events in the next 24 hours
        # list outputs one JSON array per day so we use jq to flatten
        _today="$("''${NIX_DATE}" +'%Y-%m-%d')"
        _tomorrow="$("''${NIX_DATE}" -d 'tomorrow' +'%Y-%m-%d')"
        _day_after="$("''${NIX_DATE}" -d '2 days' +'%Y-%m-%d')"

        _raw="$(
          "''${NIX_KHAL}" --config "''${KHAL_CONFIG}" \
            list \
            --json title \
            --json start \
            --json uid \
            --json all-day \
            "''${_today}" "''${_day_after}" 2>/dev/null
        )" || { printf "khal-notify: khal list failed\n" >&2; exit 1; }

        # Flatten the per-day arrays, filter empty objects and all-day events,
        # output one event per line as: <uid>TAB<start>TAB<title>
        _events="$(
          printf '%s\n' "''${_raw}" \
            | "''${NIX_JQ}" -r '
                [.[] | select(.uid != null and .uid != "" and .["all-day"] == "False")]
                | .[]
                | [.uid, .start, .title] | @tsv
              ' 2>/dev/null
        )" || { printf "khal-notify: jq parse failed\n" >&2; exit 1; }

        [ -z "''${_events:-}" ] && exit 0

        # Reminder offsets in minutes - injected from Nix at build time
        _offsets="${lib.concatStringsSep " " (map toString cfg.reminderOffsets)}"

        printf '%s\n' "''${_events}" | while IFS="$(printf '\t')" read -r _uid _start _title; do
          [ -n "''${_uid:-}" ] || continue
          [ -n "''${_start:-}" ] || continue
          [ -n "''${_title:-}" ] || continue

          # Parse event start to epoch
          # start format from khal: "2026-03-04 09:00"
          _event_epoch="$(
            TZ="''${TZ}" "''${NIX_DATE}" -d "''${_start}" +%s 2>/dev/null
          )" || { printf "khal-notify: could not parse start '%s'\n" "''${_start}" >&2; continue; }

          for _offset in ''${_offsets}; do
            # Target time = event start minus offset in seconds
            _target_epoch=$(( _event_epoch - (_offset * 60) ))

            # Only notify if we are within a 30 second window of the target
            _delta=$(( now_epoch - _target_epoch ))
            if [ "''${_delta}" -lt 0 ]; then
              _delta=$(( -_delta ))
            fi
            [ "''${_delta}" -gt 30 ] && continue

            # State file prevents duplicate notifications for same event+offset
            _state_file="''${state_dir}/''${_uid}-''${_offset}"
            [ -f "''${_state_file}" ] && continue

            # Fire notification
            "''${NIX_NOTIFY}" \
              --app-name="khal" \
              --urgency=normal \
              "''${_title}" \
              "Starting in ''${_offset} minute(s) at ''${_start}" \
              || true

            # Mark as notified
            printf '%s\n' "''${_uid}" > "''${_state_file}"
          done
        done
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
      default = [ 15 5 1 ];
      example = [ 30 15 5 1 ];
      description = ''
        List of reminder times in minutes before each event start.
        A notification will be sent at each offset.
        Default: [ 15 5 1 ]
      '';
    };

    timerIntervalSec = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 60;
      example = 60;
      description = ''
        How often the notification service runs in seconds.
        Should be 60 or less to reliably catch the 1-minute offset window.
        Default: 60
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ khalNotify ];

    programs.khal = {
      enable = true;
      locale = {
        local_timezone = "America/New_York";
        default_timezone = "America/New_York";
        timeformat = "%H:%M";
        dateformat = "%Y-%m-%d";
        datetimeformat = "%Y-%m-%d %H:%M";
        longdatetimeformat = "%a %d %b %Y %H:%M:%S %p %Z";
      };
      calendars = {
        default = {
          path = "~/.local/share/khal/calendars/default";
          color = "light blue";
        };
      };
      settings = {
        default = {
          default_calendar = "default";
        };
      };
    };

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
