{ pkgs, ... }:
{
  # Custom Nix snowflake info tooltip script
  nixVersions =
    pkgs.writeShellScriptBin "get-nix-versions" # sh
      ''
        set -eu
        os_title=""

        if [ -f "/etc/os-release" ]; then
          os=$(grep "^NAME=" </etc/os-release | cut -f2 -d= | tr -d '"')
          os_ver=$(grep "^VERSION=" </etc/os-release | cut -f2 -d= | tr -d '"')
          os_title="$os: $os_ver"
        fi

        if command -v sw_vers >/dev/null 2>&1; then
          os=$(sw_vers | grep "ProductName" | cut -f2 -d: | tr -d '[:space:]')
          os_ver=$(sw_vers | grep "ProductVersion" | cut -f2 -d: | tr -d '[:space:]')
          os_title="$os: $os_ver"
        fi

        kernelVer=$(uname -r)
        nixVer=$(nix --version)

        ${pkgs.jq}/bin/jq -c -n --arg os "$os_title" \
          --arg kernel "Kernel: $kernelVer" \
          --arg nix "$nixVer" \
          '{"tooltip": "\($os)\r\($kernel)\r\($nix)"}'
      '';

  # --- MPD Popout (refactored menus) ---
  mpdPopout =
    pkgs.writeShellScriptBin "mpd-popout" # sh
      ''
        set -eu

        MPC="${pkgs.mpc}/bin/mpc"
        ROFI="${pkgs.rofi}/bin/rofi"
        CUT="${pkgs.coreutils}/bin/cut"
        WC="${pkgs.coreutils}/bin/wc"
        TR="${pkgs.coreutils}/bin/tr"
        SED="${pkgs.gnused}/bin/sed"
        AWK="${pkgs.gawk}/bin/awk"
        GREP="${pkgs.gnugrep}/bin/grep"
        FIND="${pkgs.findutils}/bin/find"
        SORT="${pkgs.coreutils}/bin/sort"
        HEAD="${pkgs.coreutils}/bin/head"
        STAT="${pkgs.coreutils}/bin/stat"

        rofi_menu() {
          prompt="$1"; shift
          "$ROFI" -dmenu -i -p "$prompt" "$@"
        }

        rofi_multi() {
          prompt="$1"; shift
          "$ROFI" -dmenu -i -multi-select -p "$prompt (Shift+Enter select, Enter done)" "$@"
        }

        # file<TAB>pretty (pretty falls back to filename base)
        fmt_file_pretty() {
          "$AWK" -F'\t' '
            function base(s) { sub(/^.*\//,"",s); sub(/\.[^.]*$/,"",s); return s }
            {
              file=$1; pretty=$2
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", pretty)
              if (pretty=="" || pretty ~ /^[[:space:]]*—[[:space:]]*$/) pretty=base(file)
              printf "%s\t%s\n", file, pretty
            }'
        }

        # numbered queue: pos<TAB>pretty
        fmt_pos_pretty() {
          "$AWK" -F'\t' '
            function base(s) { sub(/^.*\//,"",s); sub(/\.[^.]*$/,"",s); return s }
            {
              file=$1; pretty=$2
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", pretty)
              if (pretty=="" || pretty ~ /^[[:space:]]*—[[:space:]]*$/) pretty=base(file)
              printf "%d\t%s\n", NR, pretty
            }'
        }

        add_files_from_tablist() {
          # stdin: file<TAB>pretty (multi-selected), add file column
          files="$("$CUT" -f1)" || return 0
          [ -n "''${files:-}" ] || return 0
          printf '%s\n' "$files" | while IFS= read -r f; do
            [ -n "$f" ] && "$MPC" add "$f" >/dev/null
          done
        }

        # ---------- Queue ----------
        queue_view() {
          lines="$("$MPC" -f '%file%\t%artist% — %title%' playlist 2>/dev/null | fmt_pos_pretty || true)"
          [ -n "''${lines:-}" ] || { printf '%s\n' "Queue is empty" | rofi_menu "Queue"; return 0; }
          printf '%s\n' "$lines" | rofi_menu "Queue (view)" >/dev/null || true
        }

        queue_jump() {
          lines="$("$MPC" -f '%file%\t%artist% — %title%' playlist 2>/dev/null | fmt_pos_pretty || true)"
          [ -n "''${lines:-}" ] || { printf '%s\n' "Queue is empty" | rofi_menu "Queue"; return 0; }

          sel="$(printf '%s\n' "$lines" | rofi_menu "Jump to")" || return 0
          pos="$(printf '%s' "$sel" | "$CUT" -f1 | "$TR" -d ' ')" || pos=""
          [ -n "$pos" ] || return 0
          "$MPC" play "$pos" >/dev/null
        }

        queue_delete() {
          lines="$("$MPC" -f '%file%\t%artist% — %title%' playlist 2>/dev/null | fmt_pos_pretty || true)"
          [ -n "''${lines:-}" ] || { printf '%s\n' "Queue is empty" | rofi_menu "Queue"; return 0; }

          picks="$(printf '%s\n' "$lines" | rofi_multi "Delete")" || return 0
          poss="$(printf '%s\n' "$picks" | "$CUT" -f1 | "$TR" -d ' ')" || return 0
          [ -n "''${poss:-}" ] || return 0

          # Delete highest -> lowest so indices stay valid
          printf '%s\n' "$poss" | "$SORT" -rn | while IFS= read -r p; do
            [ -n "$p" ] && "$MPC" del "$p" >/dev/null
          done
        }

        queue_clear() {
          confirm="$(printf '%s\n' "← Back" "Clear queue (confirm)" | rofi_menu "Clear Queue")" || return 0
          [ "$confirm" = "Clear queue (confirm)" ] || return 0
          "$MPC" clear >/dev/null
        }

        queue_save() {
          name="$(printf '%s' "" | "$ROFI" -dmenu -p "Playlist name" -i)" || return 0
          [ -n "$name" ] || return 0
          "$MPC" save "$name" >/dev/null
        }

        queue_menu() {
          while :; do
            choice="$(printf '%s\n' \
              "← Back" \
              "View" \
              "Jump" \
              "Delete" \
              "Clear" \
              "Save" \
              | rofi_menu "Queue")" || return 0

            case "$choice" in
              "← Back") return 0 ;;
              "View")   queue_view ;;
              "Jump")   queue_jump ;;
              "Delete") queue_delete ;;
              "Clear")  queue_clear ;;
              "Save")   queue_save ;;
            esac
          done
        }

        # ---------- Playlist ----------
        pick_playlist() {
          pls="$("$MPC" lsplaylists 2>/dev/null || true)"
          [ -n "''${pls:-}" ] || { printf '%s\n' "No playlists found" | rofi_menu "Playlists"; return 1; }
          pl="$(printf '%s\n' "← Back" "$pls" | rofi_menu "Playlists")" || return 1
          [ "$pl" = "← Back" ] && return 1
          [ -n "$pl" ] || return 1
          printf '%s' "$pl"
        }

        playlist_load_replace() {
          pl="$(pick_playlist || true)"; [ -n "''${pl:-}" ] || return 0
          confirm="$(printf '%s\n' "← Back" "Replace queue (confirm)" | rofi_menu "Load Playlist")" || return 0
          [ "$confirm" = "Replace queue (confirm)" ] || return 0
          "$MPC" clear >/dev/null
          "$MPC" load "$pl" >/dev/null
          "$MPC" play >/dev/null 2>&1 || true
        }

        playlist_append() {
          pl="$(pick_playlist || true)"; [ -n "''${pl:-}" ] || return 0
          "$MPC" load "$pl" >/dev/null
        }

        playlist_delete() {
          pl="$(pick_playlist || true)"; [ -n "''${pl:-}" ] || return 0
          confirm="$(printf '%s\n' "← Back" "Delete (confirm): $pl" | rofi_menu "Delete Playlist")" || return 0
          [ "$confirm" = "Delete (confirm): $pl" ] || return 0
          "$MPC" rm "$pl" >/dev/null
        }

        playlist_menu() {
          while :; do
            choice="$(printf '%s\n' \
              "← Back" \
              "Load (replace queue)" \
              "Append (keep queue)" \
              "Delete playlist" \
              | rofi_menu "Playlist")" || return 0

            case "$choice" in
              "← Back") return 0 ;;
              "Load (replace queue)") playlist_load_replace ;;
              "Append (keep queue)")  playlist_append ;;
              "Delete playlist")      playlist_delete ;;
            esac
          done
        }

        # ---------- Search ----------
        search_add_any() {
          picks="$(
            "$MPC" -f '%file%\t%artist% — %title%' search any "" 2>/dev/null \
              | fmt_file_pretty \
              | rofi_multi "Add (All)"
          )" || return 0
          printf '%s\n' "$picks" | add_files_from_tablist
        }

        search_add_field_prompt() {
          field="$1"
          q="$(printf '%s' "" | "$ROFI" -dmenu -p "Search ''${field}" -i)" || return 0
          [ -n "$q" ] || return 0
          picks="$(
            "$MPC" -f '%file%\t%artist% — %title%' search "$field" "$q" 2>/dev/null \
              | fmt_file_pretty \
              | rofi_multi "Add (''${field})"
          )" || return 0
          printf '%s\n' "$picks" | add_files_from_tablist
        }

        search_add_genre() {
          genres="$("$MPC" list genre 2>/dev/null || true)"
          [ -n "''${genres:-}" ] || { printf '%s\n' "No genres found" | rofi_menu "Genre"; return 0; }

          genre="$(printf '%s\n' "← Back" "$genres" | rofi_menu "Genre")" || return 0
          [ "$genre" = "← Back" ] && return 0

          picks="$(
            "$MPC" -f '%file%\t%artist% — %title%' search genre "$genre" 2>/dev/null \
              | fmt_file_pretty \
              | rofi_multi "Add (Genre)"
          )" || return 0
          printf '%s\n' "$picks" | add_files_from_tablist
        }

        search_add_newest() {
          LIMIT=500

          conf=""
          for p in \
            "''${XDG_CONFIG_HOME:-$HOME/.config}/mpd/mpd.conf" \
            "$HOME/.config/mpd/mpd.conf" \
            "/etc/mpd.conf" \
            "/etc/mpd/mpd.conf"
          do
            [ -r "$p" ] && { conf="$p"; break; }
          done

          [ -n "$conf" ] || { printf '%s\n' "mpd.conf not found" | rofi_menu "Newest"; return 0; }

          music_dir="$(
            "$SED" -n \
              -e 's/^[[:space:]]*music_directory[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
              -e "s/^[[:space:]]*music_directory[[:space:]]*'\\(.*\\)'[[:space:]]*$/\\1/p" \
              -e 's/^[[:space:]]*music_directory[[:space:]]*\(.*\)[[:space:]]*$/\1/p' \
              "$conf" | "$HEAD" -n 1
          )"
          music_dir="$(printf '%s' "$music_dir" | "$SED" 's/[[:space:]]*$//')"
          [ -n "$music_dir" ] && [ -d "$music_dir" ] || { printf '%s\n' "music_directory not set / not a dir" | rofi_menu "Newest"; return 0; }

          newest="$(
            "$FIND" "$music_dir" -type f 2>/dev/null \
              | while IFS= read -r abs; do
                  ts="$("$STAT" -c %Y "$abs" 2>/dev/null || echo 0)"
                  rel="''${abs#"$music_dir"/}"
                  base="''${rel##*/}"; base="''${base%.*}"
                  printf '%s\t%s\t%s\n' "$ts" "$rel" "$base"
                done \
              | "$SORT" -rn -k1,1 \
              | "$HEAD" -n "$LIMIT"
          )" || newest=""

          [ -n "''${newest:-}" ] || { printf '%s\n' "No files found" | rofi_menu "Newest"; return 0; }

          picks="$(
            printf '%s\n' "$newest" \
              | "$AWK" -F'\t' '{ printf "%s\t%s\n", $2, $3 }' \
              | rofi_multi "Add (Newest)"
          )" || return 0

          printf '%s\n' "$picks" | add_files_from_tablist
        }

        search_menu() {
          while :; do
            choice="$(printf '%s\n' \
              "← Back" \
              "Newest (file mtime)" \
              "Artist (prompt)" \
              "Genre (pick)" \
              "Title (prompt)" \
              "All (any)" \
              | rofi_menu "Search")" || return 0

            case "$choice" in
              "← Back") return 0 ;;
              "Newest (file mtime)") search_add_newest ;;
              "Artist (prompt)")     search_add_field_prompt artist ;;
              "Genre (pick)")        search_add_genre ;;
              "Title (prompt)")      search_add_field_prompt title ;;
              "All (any)")           search_add_any ;;
            esac
          done
        }

        # ---------- Top level ----------
        top_menu() {
          printf '%s\n' \
            "Queue" \
            "Playlist" \
            "Search" \
            "Close"
        }

        while :; do
          choice="$(top_menu | rofi_menu "MPD")" || exit 0
          case "$choice" in
            "Queue")    queue_menu ;;
            "Playlist") playlist_menu ;;
            "Search")   search_menu ;;
            "Close"|"" ) exit 0 ;;
          esac
        done
      '';
  
	# Custom mpd metadata display
  mpdWaybarTicker = 
    pkgs.writeShellScriptBin "mpd-waybar-ticker" # sh
      ''
        set -u

        MPC="${pkgs.mpc}/bin/mpc"
        JQ="${pkgs.jq}/bin/jq"

        # Ticker settings
        MAX_CHARS=35         # visible window
        GAP=" • "        # space between repeats (looks nicer than pure spaces)
        STEP=5               # chars to advance per tick

        # State file
        if [ -n "''${XDG_STATE_HOME:-}" ]; then
          STATE_DIR="$XDG_STATE_HOME"
        else
          STATE_DIR="$HOME/.local/state"
        fi
        mkdir -p "$STATE_DIR"
        STATE_FILE="$STATE_DIR/waybar-mpd-ticker.state"

        # --- Gather status and build "full text" (metadata fallback) ---
        status_out="$("$MPC" status 2>/dev/null || true)"
        st_line="$(printf '%s\n' "$status_out" | ${pkgs.gnused}/bin/sed -n '2p' 2>/dev/null || true)"

        case "$st_line" in
          "[playing]"*) status="Playing" ;;
          "[paused]"*)  status="Paused" ;;
          *)            status="Stopped" ;;
        esac

        artist="$("$MPC" -f '%artist%' current 2>/dev/null || true)"
        title="$("$MPC" -f '%title%' current 2>/dev/null || true)"
        file="$("$MPC" -f '%file%' current 2>/dev/null || true)"

        base="''${file##*/}"
        base="''${base%.*}"

        if [ -n "''${artist:-}" ] || [ -n "''${title:-}" ]; then
          if [ -n "''${artist:-}" ] && [ -n "''${title:-}" ]; then
            full="$artist ~ $title"
          elif [ -n "''${title:-}" ]; then
            full="$title"
          else
            full="$artist"
          fi
        elif [ -n "''${base:-}" ]; then
          full="$base"
        else
          full="MPD"
        fi

        # --- Load / update ticker state ---
        prev_full=""
        pos=0
        if [ -r "$STATE_FILE" ]; then
          # format: <pos>\n<full>\n
          pos="$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo 0)"
          prev_full="$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo "")"
        fi

        # reset scroll when track changes
        if [ "$full" != "$prev_full" ]; then
          pos=0
        fi

        # --- Compute displayed text window ---
        # If short, don't scroll
        # Use byte-safe-ish tools; good enough for your ASCII-ish metadata.
        full_len="$(printf '%s' "$full" | ${pkgs.coreutils}/bin/wc -c | ${pkgs.coreutils}/bin/tr -d ' ')"

        if [ "$full_len" -le "$MAX_CHARS" ]; then
          text="$full"
        else
          scroll="$full$GAP"
          scroll_len="$(printf '%s' "$scroll" | ${pkgs.coreutils}/bin/wc -c | ${pkgs.coreutils}/bin/tr -d ' ')"

          # wrap
          pos_mod=$(( pos % scroll_len ))

          # take window; if it runs off end, wrap by doubling
          doubled="$scroll$scroll"
          text="$(printf '%s' "$doubled" | ${pkgs.coreutils}/bin/cut -c $((pos_mod+1))-$((pos_mod+MAX_CHARS)) )"

          pos=$(( pos + STEP ))
        fi

        # persist state
        {
          printf '%s\n' "$pos"
          printf '%s\n' "$full"
        } > "$STATE_FILE" 2>/dev/null || true

        # Emit JSON
        "$JQ" -cn \
          --arg text "$text" \
          --arg tooltip "MPD : $full" \
          --arg alt "$status" \
          --arg class "$status" \
          '{text:$text, tooltip:$tooltip, alt:$alt, class:$class}'
      '';

  mpdShuffleWaybar =
    pkgs.writeShellScriptBin "mpd-shuffle-waybar" # sh
      ''
        set -eu
        MPC="${pkgs.mpc}/bin/mpc"
        JQ="${pkgs.jq}/bin/jq"

        # mpc status line usually contains: "random: on/off"
        class="$("$MPC" status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Eo 'random: (on|off)' | ${pkgs.gawk}/bin/awk '{print $2}' || true)"
        [ -n "$class" ] || class="off"

        "$JQ" -cn --arg text "" --arg class "$class" '{text:$text, class:$class, tooltip:"Shuffle"}'
      '';

  mpdRepeatCycle =
    pkgs.writeShellScriptBin "mpd-repeat-cycle" # sh
      ''
        set -eu
        MPC="${pkgs.mpc}/bin/mpc"
        JQ="${pkgs.jq}/bin/jq"
        GREP="${pkgs.gnugrep}/bin/grep"
        AWK="${pkgs.gawk}/bin/awk"

        status="$("$MPC" status || true)"
        rep="$(printf '%s\n' "$status" | "$GREP" -Eo 'repeat: (on|off)' | "$AWK" '{print $2}' || true)"
        sng="$(printf '%s\n' "$status" | "$GREP" -Eo 'single: (on|off)' | "$AWK" '{print $2}' || true)"

        [ -n "$rep" ] || rep="off"
        [ -n "$sng" ] || sng="off"

        # Determine state
        # 0 = off, 1 = playlist, 2 = track
        if [ "$rep" = "off" ]; then
          state="off"
          icon="󰑗"
          tip="Repeat: off"
        elif [ "$sng" = "on" ]; then
          state="track"
          icon="󰑘"
          tip="Repeat: track"
        else
          state="playlist"
          icon="󰑖"
          tip="Repeat: playlist"
        fi

        "$JQ" -cn --arg text "$icon" --arg class "$state" --arg tooltip "$tip" \
          '{text:$text, class:$class, tooltip:$tooltip}'
      '';

  mpdRepeatCycleClick =
    pkgs.writeShellScriptBin "mpd-repeat-cycle-click" # sh
      ''
        set -eu
        MPC="${pkgs.mpc}/bin/mpc"
        GREP="${pkgs.gnugrep}/bin/grep"
        AWK="${pkgs.gawk}/bin/awk"

        status="$("$MPC" status || true)"
        rep="$(printf '%s\n' "$status" | "$GREP" -Eo 'repeat: (on|off)' | "$AWK" '{print $2}' || true)"
        sng="$(printf '%s\n' "$status" | "$GREP" -Eo 'single: (on|off)' | "$AWK" '{print $2}' || true)"

        [ -n "$rep" ] || rep="off"
        [ -n "$sng" ] || sng="off"

        # Cycle:
        # off -> playlist -> track -> off
        if [ "$rep" = "off" ]; then
          "$MPC" repeat on >/dev/null
          "$MPC" single off >/dev/null
        elif [ "$sng" = "off" ]; then
          "$MPC" repeat on >/dev/null
          "$MPC" single on >/dev/null
        else
          "$MPC" repeat off >/dev/null
          "$MPC" single off >/dev/null
        fi
      '';
}
