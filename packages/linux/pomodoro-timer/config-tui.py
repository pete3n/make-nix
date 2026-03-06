import curses
import sys
import os
import json
import subprocess

STATE_FILE = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.join(
        os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
        "pomodoro",
        "state.json",
    )
)

CONFIG_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "pomodoro",
    "config.json",
)


def read_config():
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except Exception:
        return {
            "activity_intervals": [25, 50, 90],
            "rest_intervals": [5, 10, 15],
            "activity_playlist": "",
            "rest_playlist": "",
            "activity_image": "",
            "rest_image": "",
            "image_display_duration": 5,
            "default_activity_name": "Activity",
        }


CFG = read_config()
ACT_INTERVALS = CFG["activity_intervals"]
RST_INTERVALS = CFG["rest_intervals"]
DEFAULT_NAME = CFG["default_activity_name"]
MPC = "mpc"


def read_state():
    if not os.path.exists(STATE_FILE):
        return {
            "status": "stopped",
            "mode": "activity",
            "remaining": ACT_INTERVALS[0] * 60,
            "activity_name": DEFAULT_NAME,
            "activity_idx": 0,
            "rest_idx": 0,
            "restore": {"track": "", "elapsed": 0, "status": "stopped"},
            "activity": {"track": "", "elapsed": 0},
            "rest": {"track": "", "elapsed": 0},
        }
    with open(STATE_FILE) as f:
        return json.load(f)


def write_state(s):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=2)
    os.replace(tmp, STATE_FILE)


def mpc_run(*args):
    try:
        return (
            subprocess.check_output([MPC] + list(args), stderr=subprocess.DEVNULL)
            .decode()
            .strip()
        )
    except Exception:
        return ""


def save_mpd_state():
    track = mpc_run("-f", "%file%", "current")
    elapsed = "0"
    status_out = mpc_run("status")
    for line in status_out.splitlines():
        if "time:" in line:
            parts = line.strip().split()
            for p in parts:
                if ":" in p and p.split(":")[0].isdigit():
                    elapsed = p.split(":")[0]
                    break
    mpd_status = "stopped"
    if "[playing]" in status_out:
        mpd_status = "playing"
    elif "[paused]" in status_out:
        mpd_status = "paused"
    return track, elapsed, mpd_status


def restore_mpd_state(track, elapsed, status):
    mpc_run("clear")
    if track:
        mpc_run("add", track)
        mpc_run("play", "1")
        if int(elapsed) > 0:
            mpc_run("seek", str(elapsed))
    if status == "paused":
        mpc_run("pause")
    elif status == "stopped":
        mpc_run("stop")


def start_timer(s):
    track, elapsed, mpd_status = save_mpd_state()
    s["restore"] = {"track": track, "elapsed": int(elapsed), "status": mpd_status}
    s["activity"] = {"track": "", "elapsed": 0}
    s["rest"] = {"track": "", "elapsed": 0}
    s["status"] = "running"
    s["mode"] = "activity"
    s["remaining"] = ACT_INTERVALS[s["activity_idx"]] * 60
    mpc_run("clear")
    mpc_run("load", CFG["activity_playlist"])
    mpc_run("repeat", "on")
    mpc_run("play")
    write_state(s)

def stop_timer(s):
    # Close any open transition image
    state_dir = os.path.join(
        os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
        "pomodoro",
    )
    pidfile = os.path.join(state_dir, "swayimg.pid")
    if os.path.exists(pidfile):
        try:
            with open(pidfile) as f:
                pid = int(f.read().strip())
            os.kill(pid, 9)
        except Exception:
            pass
        try:
            os.remove(pidfile)
        except Exception:
            pass

    restore = s.get("restore", {})
    restore_mpd_state(
        restore.get("track", ""),
        restore.get("elapsed", 0),
        restore.get("status", "stopped"),
    )
    if os.path.exists(STATE_FILE):
        os.remove(STATE_FILE)


def main(stdscr):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_YELLOW, -1)
    curses.init_pair(4, curses.COLOR_WHITE, -1)
    curses.init_pair(5, curses.COLOR_RED, -1)

    curses.mousemask(curses.ALL_MOUSE_EVENTS)
    stdscr.keypad(True)
    stdscr.timeout(100)

    s = read_state()
    editing_name = False
    name_buf = s["activity_name"]
    cursor = 0
    NUM_FIELDS = 4

    def draw():
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        def center(y, text, attr=0):
            x = max(0, (w - len(text)) // 2)
            try:
                stdscr.addstr(y, x, text, attr)
            except curses.error:
                pass

        def interval_row(y, label, value, selected, left_x, right_x, val_x):
            attr_l = curses.color_pair(4) | (curses.A_BOLD if selected else 0)
            attr_v = curses.color_pair(2) | (curses.A_BOLD if selected else 0)
            attr_a = curses.color_pair(3)
            try:
                stdscr.addstr(y, 2, label, attr_l)
                stdscr.addstr(y, left_x, "<<", attr_a)
                stdscr.addstr(y, val_x, value, attr_v)
                stdscr.addstr(y, right_x, ">>", attr_a)
            except curses.error:
                pass

        center(1, "Pomodoro Timer", curses.color_pair(1) | curses.A_BOLD)
        center(2, "─" * 40, curses.color_pair(1))

        # Activity name row
        name_disp = (name_buf if editing_name else s["activity_name"]) + (
            "_" if editing_name else ""
        )
        name_sel = cursor == 0
        try:
            stdscr.addstr(
                4,
                2,
                "Activity: ",
                curses.color_pair(4) | (curses.A_BOLD if name_sel else 0),
            )
            stdscr.addstr(
                4,
                12,
                name_disp,
                curses.color_pair(2) | (curses.A_BOLD if name_sel else 0),
            )
        except curses.error:
            pass

        # Interval rows
        act_val = str(ACT_INTERVALS[s["activity_idx"]]) + " min"
        interval_row(6, "Activity interval: ", act_val, cursor == 1, 22, 32, 25)

        rst_val = str(RST_INTERVALS[s["rest_idx"]]) + " min"
        interval_row(8, "Rest interval:     ", rst_val, cursor == 2, 22, 32, 25)

        center(10, "─" * 40, curses.color_pair(1))

        # Start / Stop buttons
        is_running = s["status"] == "running"
        btn_y = 12
        start_x = max(0, w // 2 - 12)
        stop_x = max(0, w // 2 + 2)
        btn_sel = cursor == 3
        start_attr = (
            curses.color_pair(2)
            | (curses.A_BOLD if btn_sel else 0)
            | (curses.A_DIM if is_running else 0)
        )
        stop_attr = (
            curses.color_pair(5)
            | (curses.A_BOLD if btn_sel else 0)
            | (curses.A_DIM if not is_running else 0)
        )
        try:
            stdscr.addstr(btn_y, start_x, "[ Start ]", start_attr)
            stdscr.addstr(btn_y, stop_x, "[ Stop  ]", stop_attr)
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

        center(
            16,
            "hjkl / arrows: navigate   Enter: select   q: quit",
            curses.color_pair(4),
        )

        stdscr.refresh()

    def handle_mouse(s):
        nonlocal cursor, editing_name, name_buf
        try:
            _, mx, my, _, _ = curses.getmouse()
        except curses.error:
            return False
        h, w = stdscr.getmaxyx()
        start_x = w // 2 - 12
        stop_x = w // 2 + 2
        if my == 4:
            cursor = 0
            editing_name = True
            name_buf = s["activity_name"]
        elif my == 6:
            cursor = 1
            if mx in range(22, 24):
                s["activity_idx"] = (s["activity_idx"] - 1) % len(ACT_INTERVALS)
            elif mx in range(32, 34):
                s["activity_idx"] = (s["activity_idx"] + 1) % len(ACT_INTERVALS)
        elif my == 8:
            cursor = 2
            if mx in range(22, 24):
                s["rest_idx"] = (s["rest_idx"] - 1) % len(RST_INTERVALS)
            elif mx in range(32, 34):
                s["rest_idx"] = (s["rest_idx"] + 1) % len(RST_INTERVALS)
        elif my == 12:
            cursor = 3
            if start_x <= mx <= start_x + 8:
                if not is_running:
                    start_timer(s)
                    return True
            elif stop_x <= mx <= stop_x + 8:
                if is_running:
                    stop_timer(s)
                    return True
        return False

    while True:
        is_running = s["status"] == "running"
        draw()
        key = stdscr.getch()

        if key == ord("q"):
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
            if key in (ord("k"), curses.KEY_UP):
                cursor = (cursor - 1) % NUM_FIELDS
            elif key in (ord("j"), curses.KEY_DOWN):
                cursor = (cursor + 1) % NUM_FIELDS
            elif key in (ord("h"), curses.KEY_LEFT):
                if cursor == 1:
                    s["activity_idx"] = (s["activity_idx"] - 1) % len(ACT_INTERVALS)
                    write_state(s)
                elif cursor == 2:
                    s["rest_idx"] = (s["rest_idx"] - 1) % len(RST_INTERVALS)
                    write_state(s)
            elif key in (ord("l"), curses.KEY_RIGHT):
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
                    if not is_running:
                        start_timer(s)
                    else:
                        stop_timer(s)
                    break


curses.wrapper(main)
