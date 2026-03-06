{ config, pkgs, lib, ... }:
let
  cfg = config.programs.pomodoro;

  stateDir = "$XDG_STATE_HOME/pomodoro";
  stateFile = "${stateDir}/state";

  mpc = "${pkgs.mpc}/bin/mpc";
  jq = "${pkgs.jq}/bin/jq";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  python = "${pkgs.python3}/bin/python3";

  pomodoroTicker = pkgs.writeShellScriptBin "pomodoro-ticker" # sh
    ''
      set -u

      NIX_MPC="${mpc}"
      NIX_JQ="${jq}"

      STATE_DIR="${stateDir}"
      STATE_FILE="${stateFile}"

      mkdir -p "''${STATE_DIR}"

      # Default clock output when stopped
      _clock_text="$(date +'%H:%M')"
      _default="$(printf '<span color="#7ebae4">   </span>%s' "''${_clock_text}")"

      if [ ! -r "''${STATE_FILE}" ]; then
        "$NIX_JQ" -cn \
          --arg text "''${_default}" \
          --arg class "clock" \
          '{text:$text,tooltip:"",class:$class}'
        exit 0
      fi

      # Read state
      _status="$(sed -n '1p' "''${STATE_FILE}")"
      _mode="$(sed -n '2p' "''${STATE_FILE}")"
      _remaining="$(sed -n '3p' "''${STATE_FILE}")"
      _activity_name="$(sed -n '4p' "''${STATE_FILE}")"

      if [ "''${_status}" != "running" ]; then
        "$NIX_JQ" -cn \
          --arg text "''${_default}" \
          --arg class "clock" \
          '{text:$text,tooltip:"",class:$class}'
        exit 0
      fi

      # Decrement timer
      _remaining=$(( _remaining - 1 ))

      if [ "''${_remaining}" -le 0 ]; then
        # Trigger transition
        "${lib.getExe pomodoroTransition}" &
        exit 0
      fi

      # Persist decremented remaining
      {
        printf '%s\n' "''${_status}"
        printf '%s\n' "''${_mode}"
        printf '%s\n' "''${_remaining}"
        sed -n '4,$p' "''${STATE_FILE}"
      } > "''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"

      # Format countdown MM:SS
      _mins=$(( _remaining / 60 ))
      _secs=$(( _remaining % 60 ))
      _countdown="$(printf '%d:%02d' "''${_mins}" "''${_secs}")"

      if [ "''${_mode}" = "activity" ]; then
        _label="''${_activity_name:-${cfg.defaultActivityName}}"
        _class="activity"
      else
        _label="Rest"
        _class="rest"
      fi

      _text="''${_label}: ''${_countdown}"

      "$NIX_JQ" -cn \
        --arg text "''${_text}" \
        --arg class "''${_class}" \
        '{text:$text,tooltip:"",class:$class}'
    '';

  pomodoroTransition = pkgs.writeShellScriptBin "pomodoro-transition" # sh
    ''
      set -u

      NIX_MPC="${mpc}"
      STATE_FILE="${stateFile}"

      if [ ! -r "''${STATE_FILE}" ]; then
        exit 0
      fi

      _mode="$(sed -n '2p' "''${STATE_FILE}")"
      _activity_name="$(sed -n '4p' "''${STATE_FILE}")"
      _activity_idx="$(sed -n '5p' "''${STATE_FILE}")"
      _rest_idx="$(sed -n '6p' "''${STATE_FILE}")"
      _activity_playlist="${cfg.activityPlaylist}"
      _rest_playlist="${cfg.restPlaylist}"

      # Switch mode
      if [ "''${_mode}" = "activity" ]; then
        _next_mode="rest"
        _next_interval_idx="''${_rest_idx}"
        _next_playlist="''${_rest_playlist}"
        _image_path="${cfg.restImage}"
        _next_interval_secs=$(( ${toString (builtins.elemAt cfg.restIntervals 0)} * 60 ))
      else
        _next_mode="activity"
        _next_interval_idx="''${_activity_idx}"
        _next_playlist="''${_activity_playlist}"
        _image_path="${cfg.activityImage}"
        _next_interval_secs=$(( ${toString (builtins.elemAt cfg.activityIntervals 0)} * 60 ))
      fi

      # Get correct interval from index
      if [ "''${_next_mode}" = "activity" ]; then
        _next_interval_secs="$(${lib.getExe pomodoroGetInterval} activity "''${_activity_idx}")"
      else
        _next_interval_secs="$(${lib.getExe pomodoroGetInterval} rest "''${_rest_idx}")"
      fi

      # Save MPD position
      _mpd_track="$("$NIX_MPC" -f '%file%' current 2>/dev/null || true)"
      _mpd_position="$("$NIX_MPC" status 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -n 's/.*(\([0-9]*\)%).*/\1/p' | head -1 || true)"
      _mpd_elapsed="$("$NIX_MPC" status 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -n '3p' \
        | ${pkgs.gnused}/bin/sed 's/.*time: *\([0-9]*\):.*/\1/' || true)"

      # Switch MPD playlist
      "$NIX_MPC" clear 2>/dev/null || true
      "$NIX_MPC" load "''${_next_playlist}" 2>/dev/null || true
      "$NIX_MPC" play 2>/dev/null || true

      # Update state file
      {
        printf 'running\n'
        printf '%s\n' "''${_next_mode}"
        printf '%s\n' "''${_next_interval_secs}"
        printf '%s\n' "''${_activity_name}"
        printf '%s\n' "''${_activity_idx}"
        printf '%s\n' "''${_rest_idx}"
        printf '%s\n' "''${_mpd_track}"
        printf '%s\n' "''${_mpd_elapsed:-0}"
        sed -n '9p' "''${STATE_FILE}"
      } > "''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"

      # Show transition image
      "${lib.getExe pomodoroShowImage}" "''${_image_path}" &
    '';

  pomodoroGetInterval = pkgs.writeShellScriptBin "pomodoro-get-interval" # sh
    ''
      set -u
      _mode="''${1:-activity}"
      _idx="''${2:-0}"

      if [ "''${_mode}" = "activity" ]; then
        _intervals="${lib.concatStringsSep " " (map toString cfg.activityIntervals)}"
      else
        _intervals="${lib.concatStringsSep " " (map toString cfg.restIntervals)}"
      fi

      _i=0
      _result=""
      for _val in ''${_intervals}; do
        if [ "''${_i}" = "''${_idx}" ]; then
          _result="''${_val}"
          break
        fi
        _i=$(( _i + 1 ))
      done

      # Default to first if index out of range
      if [ -z "''${_result}" ]; then
        _result="$(printf '%s' "''${_intervals}" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      fi

      printf '%s\n' $(( _result * 60 ))
    '';

  pomodoroShowImage = pkgs.writeShellScriptBin "pomodoro-show-image" # sh
    ''
      set -u

      _image_path="''${1:-}"

      if [ -z "''${_image_path}" ] || [ ! -e "''${_image_path}" ]; then
        exit 0
      fi

      # Pick random image if directory
      if [ -d "''${_image_path}" ]; then
        _image="$(${pkgs.findutils}/bin/find "''${_image_path}" \
          -maxdepth 1 \
          -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
          | ${pkgs.coreutils}/bin/shuf -n1)"
      else
        _image="''${_image_path}"
      fi

      if [ -z "''${_image}" ]; then
        exit 0
      fi

      # Get image dimensions
      _img_w="$(${pkgs.imagemagick}/bin/identify -format '%w' "''${_image}" 2>/dev/null || printf '800')"
      _img_h="$(${pkgs.imagemagick}/bin/identify -format '%h' "''${_image}" 2>/dev/null || printf '600')"

      # Get screen dimensions via hyprctl (first monitor)
      _screen_w="$(${hyprctl} monitors -j \
        | ${jq} '.[0].width' 2>/dev/null || printf '1920')"
      _screen_h="$($(hyprctl} monitors -j \
        | ${jq} '.[0].height' 2>/dev/null || printf '1080')"

      # 33% of screen
      _max_w=$(( _screen_w / 3 ))
      _max_h=$(( _screen_h / 3 ))

      # Use smaller of image size or 33% screen
      if [ "''${_img_w}" -lt "''${_max_w}" ]; then
        _win_w="''${_img_w}"
      else
        _win_w="''${_max_w}"
      fi

      if [ "''${_img_h}" -lt "''${_max_h}" ]; then
        _win_h="''${_img_h}"
      else
        _win_h="''${_max_h}"
      fi

      # Launch alacritty with swayimg, auto-close after display duration
      ${pkgs.alacritty}/bin/alacritty \
        --option "window.dimensions.columns=1" \
        --option "window.dimensions.lines=1" \
        --option "window.decorations=none" \
        --option "window.startup_mode=Windowed" \
        -e sh -c \
        "${pkgs.swayimg}/bin/swayimg ''${_image}' & \
         sleep ${toString cfg.imageDisplayDuration} && \
         kill %1 2>/dev/null" &
    '';

  pomodoroConfig = pkgs.writeShellScriptBin "pomodoro-config" # sh
    ''
      set -u
      ${pkgs.alacritty}/bin/alacritty \
        --option "window.dimensions.columns=60" \
        --option "window.dimensions.lines=20" \
        --option "window.decorations=none" \
        --title "Pomodoro" \
        -e ${python} ${pomodoroConfigPy} \
          "${stateFile}" \
          "${lib.concatStringsSep "," (map toString cfg.activityIntervals)}" \
          "${lib.concatStringsSep "," (map toString cfg.restIntervals)}" \
          "${cfg.defaultActivityName}" \
          "${mpc}" \
    '';

  pomodoroConfigPy = pkgs.writeText "pomodoro-config.py" # python
    ''
      import curses
      import sys
      import os
      import subprocess

      STATE_FILE    = sys.argv[1]
      ACT_INTERVALS = [int(x) for x in sys.argv[2].split(",")]
      RST_INTERVALS = [int(x) for x in sys.argv[3].split(",")]
      DEFAULT_NAME  = sys.argv[4]
			NIX_MPC       = sys.argv[5]

      def read_state():
          if not os.path.exists(STATE_FILE):
              return {
                  "status": "stopped",
                  "mode": "activity",
                  "remaining": ACT_INTERVALS[0] * 60,
                  "activity_name": DEFAULT_NAME,
                  "activity_idx": 0,
                  "rest_idx": 0,
                  "mpd_track": "",
                  "mpd_elapsed": "0",
                  "mpd_status": "stopped",
              }
          with open(STATE_FILE) as f:
              lines = f.read().splitlines()
          def _get(i, default=""):
              return lines[i] if i < len(lines) else default
          return {
              "status":        _get(0, "stopped"),
              "mode":          _get(1, "activity"),
              "remaining":     int(_get(2, str(ACT_INTERVALS[0] * 60))),
              "activity_name": _get(3, DEFAULT_NAME),
              "activity_idx":  int(_get(4, "0")),
              "rest_idx":      int(_get(5, "0")),
              "mpd_track":     _get(6, ""),
              "mpd_elapsed":   _get(7, "0"),
              "mpd_status":    _get(8, "stopped"),
          }

      def write_state(s):
          os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
          tmp = STATE_FILE + ".tmp"
          with open(tmp, "w") as f:
              f.write(s["status"]        + "\n")
              f.write(s["mode"]          + "\n")
              f.write(str(s["remaining"])+ "\n")
              f.write(s["activity_name"] + "\n")
              f.write(str(s["activity_idx"]) + "\n")
              f.write(str(s["rest_idx"]) + "\n")
              f.write(s["mpd_track"]     + "\n")
              f.write(s["mpd_elapsed"]   + "\n")
              f.write(s["mpd_status"]    + "\n")
          os.replace(tmp, STATE_FILE)

      def mpc_run(*args):
          try:
              return subprocess.check_output(
                  [NIX_MPC] + list(args),
                  stderr=subprocess.DEVNULL
              ).decode().strip()
          except Exception:
              return ""

      def save_mpd_state():
          track   = mpc_run("-f", "%file%", "current")
          elapsed = "0"
          status_out = mpc_run("status")
          for line in status_out.splitlines():
              if "time:" in line:
                  # time: elapsed:total
                  parts = line.strip().split()
                  for p in parts:
                      if ":" in p and p.split(":")[0].isdigit():
                          elapsed = p.split(":")[0]
                          break
          mpd_status = "stopped"
          status_line = mpc_run("status")
          if "[playing]" in status_line:
              mpd_status = "playing"
          elif "[paused]" in status_line:
              mpd_status = "paused"
          return track, elapsed, mpd_status

      def restore_mpd_state(s):
          mpc_run("clear")
          # Re-add original playlist context - load by finding track
          if s["mpd_track"]:
              mpc_run("add", s["mpd_track"])
              mpc_run("play", "1")
              elapsed = int(s["mpd_elapsed"])
              if elapsed > 0:
                  mpc_run("seek", str(elapsed))
          if s["mpd_status"] == "paused":
              mpc_run("pause")
          elif s["mpd_status"] == "stopped":
              mpc_run("stop")

      def start_timer(s):
          track, elapsed, mpd_status = save_mpd_state()
          s["mpd_track"]   = track
          s["mpd_elapsed"] = elapsed
          s["mpd_status"]  = mpd_status
          s["status"]      = "running"
          s["mode"]        = "activity"
          s["remaining"]   = ACT_INTERVALS[s["activity_idx"]] * 60
          # Start activity playlist
          mpc_run("clear")
          mpc_run("load", "${cfg.activityPlaylist}")
          mpc_run("play")
          write_state(s)

      def stop_timer(s):
          restore_mpd_state(s)
          s["status"] = "stopped"
          # Clear state file
          if os.path.exists(STATE_FILE):
              os.remove(STATE_FILE)

      def main(stdscr):
          curses.curs_set(0)
          curses.start_color()
          curses.use_default_colors()
          curses.init_pair(1, curses.COLOR_CYAN,    -1)  # title
          curses.init_pair(2, curses.COLOR_GREEN,   -1)  # value
          curses.init_pair(3, curses.COLOR_YELLOW,  -1)  # arrows
          curses.init_pair(4, curses.COLOR_WHITE,   -1)  # label
          curses.init_pair(5, curses.COLOR_RED,     -1)  # stop
          curses.init_pair(6, curses.COLOR_MAGENTA, -1)  # cursor

          curses.mousemask(curses.ALL_MOUSE_EVENTS)
          stdscr.keypad(True)
          stdscr.timeout(100)

          s = read_state()

          # Editing state
          editing_name = False
          name_buf     = s["activity_name"]
          # Cursor field: 0=name, 1=act_interval, 2=rst_interval, 3=start/stop
          cursor       = 0
          NUM_FIELDS   = 4

          def draw():
              stdscr.erase()
              h, w = stdscr.getmaxyx()

              def center(y, text, attr=0):
                  x = max(0, (w - len(text)) // 2)
                  try:
                      stdscr.addstr(y, x, text, attr)
                  except curses.error:
                      pass

              def row(y, label, value, sel, left_x, right_x, val_x):
                  attr_l = curses.color_pair(4)
                  attr_v = curses.color_pair(2)
                  attr_a = curses.color_pair(3)
                  if sel:
                      attr_l |= curses.A_BOLD
                      attr_v |= curses.A_BOLD
                  try:
                      stdscr.addstr(y, 2, label, attr_l)
                      stdscr.addstr(y, left_x,  "<<", attr_a)
                      stdscr.addstr(y, val_x,   value, attr_v)
                      stdscr.addstr(y, right_x, ">>", attr_a)
                  except curses.error:
                      pass

              center(1, "Pomodoro Timer", curses.color_pair(1) | curses.A_BOLD)
              center(2, "─" * 30, curses.color_pair(1))

              # Activity name row
              name_label = "Activity: "
              name_val   = name_buf if editing_name else s["activity_name"]
              name_disp  = name_val + ("_" if editing_name else "")
              name_sel   = (cursor == 0)
              name_attr  = curses.color_pair(2)
              if name_sel:
                  name_attr |= curses.A_BOLD
              try:
                  stdscr.addstr(4, 2, name_label,
                      curses.color_pair(4) | (curses.A_BOLD if name_sel else 0))
                  stdscr.addstr(4, 2 + len(name_label), name_disp, name_attr)
              except curses.error:
                  pass

              # Activity interval row
              act_val = str(ACT_INTERVALS[s["activity_idx"]]) + " min"
              row(6, "Activity interval: ", act_val,
                  cursor == 1, 22, 32, 25)

              # Rest interval row
              rst_val = str(RST_INTERVALS[s["rest_idx"]]) + " min"
              row(8, "Rest interval:     ", rst_val,
                  cursor == 2, 22, 32, 25)

              center(10, "─" * 30, curses.color_pair(1))

              # Start / Stop buttons
              is_running = s["status"] == "running"
              btn_start = "[ Start ]"
              btn_stop  = "[ Stop  ]"
              btn_y     = 12
              start_x   = max(0, w // 2 - 12)
              stop_x    = max(0, w // 2 + 2)
              start_attr = curses.color_pair(2)
              stop_attr  = curses.color_pair(5)
              if cursor == 3:
                  start_attr |= curses.A_BOLD
                  stop_attr  |= curses.A_BOLD
              if is_running:
                  start_attr |= curses.A_DIM
              try:
                  stdscr.addstr(btn_y, start_x, btn_start, start_attr)
                  stdscr.addstr(btn_y, stop_x,  btn_stop,  stop_attr)
              except curses.error:
                  pass

              # Status line
              status_str = "Status: " + s["status"].upper()
              if s["status"] == "running":
                  mins = s["remaining"] // 60
                  secs = s["remaining"] % 60
                  status_str += "  |  " + s["mode"].capitalize()
                  status_str += "  " + str(mins) + ":" + str(secs).zfill(2)
              center(14, status_str, curses.color_pair(4))

              center(16, "hjkl/arrows: navigate   Enter: select   q: quit",
                  curses.color_pair(4))

              stdscr.refresh()

          # Map click positions for mouse support
          def handle_mouse(s):
              nonlocal cursor, editing_name, name_buf
              try:
                  _, mx, my, _, _ = curses.getmouse()
              except curses.error:
                  return False
              h, w = stdscr.getmaxyx()
              start_x = w // 2 - 12
              stop_x  = w // 2 + 2
              # Name row click
              if my == 4:
                  cursor = 0
                  editing_name = True
                  name_buf = s["activity_name"]
              # Activity interval arrows
              elif my == 6:
                  cursor = 1
                  if 22 <= mx <= 23:
                      s["activity_idx"] = (s["activity_idx"] - 1) % len(ACT_INTERVALS)
                  elif 32 <= mx <= 33:
                      s["activity_idx"] = (s["activity_idx"] + 1) % len(ACT_INTERVALS)
              # Rest interval arrows
              elif my == 8:
                  cursor = 2
                  if 22 <= mx <= 23:
                      s["rest_idx"] = (s["rest_idx"] - 1) % len(RST_INTERVALS)
                  elif 32 <= mx <= 33:
                      s["rest_idx"] = (s["rest_idx"] + 1) % len(RST_INTERVALS)
              # Buttons
              elif my == 12:
                  cursor = 3
                  if start_x <= mx <= start_x + 8:
                      if s["status"] != "running":
                          start_timer(s)
                          return True
                  elif stop_x <= mx <= stop_x + 8:
                      if s["status"] == "running":
                          stop_timer(s)
                          return True
              return False

          while True:
              draw()
              key = stdscr.getch()

              if key == ord('q'):
                  break

              elif key == curses.KEY_MOUSE:
                  if handle_mouse(s):
                      break
                  write_state(s)

              elif editing_name:
                  if key in (curses.KEY_ENTER, 10, 13):
                      s["activity_name"] = name_buf
                      editing_name = False
                      write_state(s)
                  elif key in (curses.KEY_BACKSPACE, 127, 8):
                      name_buf = name_buf[:-1]
                  elif 32 <= key <= 126:
                      name_buf += chr(key)

              else:
                  # Navigation
                  if key in (ord('k'), curses.KEY_UP):
                      cursor = (cursor - 1) % NUM_FIELDS
                  elif key in (ord('j'), curses.KEY_DOWN):
                      cursor = (cursor + 1) % NUM_FIELDS
                  elif key in (ord('h'), curses.KEY_LEFT):
                      if cursor == 1:
                          s["activity_idx"] = (s["activity_idx"] - 1) % len(ACT_INTERVALS)
                          write_state(s)
                      elif cursor == 2:
                          s["rest_idx"] = (s["rest_idx"] - 1) % len(RST_INTERVALS)
                          write_state(s)
                  elif key in (ord('l'), curses.KEY_RIGHT):
                      if cursor == 1:
                          s["activity_idx"] = (s["activity_idx"] + 1) % len(ACT_INTERVALS)
                          write_state(s)
                      elif cursor == 2:
                          s["rest_idx"] = (s["rest_idx"] + 1) % len(RST_INTERVALS)
                          write_state(s)
                  elif key in (curses.KEY_ENTER, 10, 13):
                      if cursor == 0:
                          editing_name = True
                          name_buf = s["activity_name"]
                      elif cursor == 3:
                          if s["status"] != "running":
                              start_timer(s)
                          else:
                              stop_timer(s)
                          break

      curses.wrapper(main)
    '';

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
    home.packages = [
      pomodoroTicker
      pomodoroTransition
      pomodoroConfig
      pomodoroShowImage
      pomodoroGetInterval
    ];
  };
}
