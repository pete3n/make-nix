{
  lib,
  makeNixLib,
  makeNixAttrs,
  pkgs,
  ...
}:
let
  mpdScripts = lib.optionalAttrs (makeNixLib.hasTag "mpd" makeNixAttrs.tags) rec {
    # MPD Rofi menu
    mpdPopout =
      pkgs.writeShellScriptBin "mpd-popout" # sh
        ''
          set -u

          MPC=${pkgs.mpc}/bin/mpc
          ROFI=${pkgs.rofi}/bin/rofi
          AWK=${pkgs.gawk}/bin/awk
          FIND=${pkgs.findutils}/bin/find

          rofi_menu() {
          	_prompt="''${1}"; shift
          	"''${ROFI}" -dmenu -i -p "''${_prompt}" "$@"
          }

          rofi_multi() {
          	_prompt="''${1}"; shift
          	"''${ROFI}" -dmenu -i -multi-select -p "''${_prompt}" "$@"
          }

          # file<TAB>pretty (pretty falls back to filename base)
          fmt_file_pretty() {
          	"''${AWK}" -F'\t' '
          		function base(s) { sub(/^.*\//,"",s); sub(/\.[^.]*$/,"",s); return s }
          		{
          			_file=$1; _pretty=$2
          			gsub(/^[[:space:]]+|[[:space:]]+$/, "", _pretty)
          			if (_pretty=="" || _pretty ~ /^[[:space:]]*—[[:space:]]*$/) _pretty=base(_file)
          			printf "%s\t%s\n", _file, _pretty
          		}'
          }

          # numbered queue: pos<TAB>pretty
          fmt_pos_pretty() {
          	"''${AWK}" -F'\t' '
          		function base(s) { sub(/^.*\//,"",s); sub(/\.[^.]*$/,"",s); return s }
          		{
          			_file=$1; _pretty=$2
          			gsub(/^[[:space:]]+|[[:space:]]+$/, "", _pretty)
          			if (_pretty=="" || _pretty ~ /^[[:space:]]*—[[:space:]]*$/) _pretty=base(_file)
          			printf "%d\t%s\n", NR, _pretty
          		}'
          }

          add_files_from_tablist() {
          	# stdin: file<TAB>pretty (multi-selected), add file column
          	_files="$(cut -f1)" || return 0
          	[ -n "''${_files:-}" ] || return 0
          	printf '%s\n' "''${_files}" | while IFS= read -r _file; do
          		[ -n "''${_file}" ] && "''${MPC}" add "''${_file}" >/dev/null
          	done
          }

          queue_jump() {
          	_lines="$("''${MPC}" -f '%file%\t%artist% — %title%' playlist 2>/dev/null \
          		| fmt_pos_pretty || true)"
          	[ -n "''${_lines:-}" ] || {
          		printf '%s\n' "Queue is empty" | rofi_menu "Queue"
          		return 0
          	}
          	_sel="$(printf '%s\n' "''${_lines}" | rofi_menu "Jump to")" || return 0
          	_pos="$(printf '%s' "''${_sel}" | cut -f1 | tr -d ' ')" || _pos=""
          	[ -n "''${_pos:-}" ] || return 0
          	"''${MPC}" play "''${_pos}" >/dev/null
          }

          queue_delete() {
          	_lines="$("''${MPC}" -f '%file%\t%artist% — %title%' playlist 2>/dev/null \
          		| fmt_pos_pretty || true)"
          	[ -n "''${_lines:-}" ] || {
          		printf '%s\n' "Queue is empty" | rofi_menu "Queue"
          		return 0
          	}
          	_picks="$(printf '%s\n' "''${_lines}" | rofi_multi "Delete")" || return 0
          	_poss="$(printf '%s\n' "''${_picks}" | cut -f1 | tr -d ' ')" || return 0
          	[ -n "''${_poss:-}" ] || return 0
          	# Delete highest -> lowest so indices stay valid
          	printf '%s\n' "''${_poss}" | sort -rn | while IFS= read -r _pos; do
          		[ -n "''${_pos}" ] && "''${MPC}" del "''${_pos}" >/dev/null
          	done
          }

          queue_clear() {
          	_confirm="$(printf '%s\n' "← Back" "Clear queue (confirm)" \
          		| rofi_menu "Clear Queue")" || return 0
          	[ "''${_confirm}" = "Clear queue (confirm)" ] || return 0
          	"''${MPC}" clear >/dev/null
          }

          queue_save() {
          	_name="$(printf '%s' "" | "''${ROFI}" -dmenu -p "Playlist name" -i)" || return 0
          	[ -n "''${_name:-}" ] || return 0
          	"''${MPC}" save "''${_name}" >/dev/null
          }

          queue_menu() {
          	while :; do
          		_choice="$(printf '%s\n' \
          			"← Back" \
          			"Jump" \
          			"Delete" \
          			"Clear" \
          			"Save" \
          			| rofi_menu "Queue")" || return 0
          		case "''${_choice}" in
          			"← Back") return 0 ;;
          			"Jump")   queue_jump ;;
          			"Delete") queue_delete ;;
          			"Clear")  queue_clear ;;
          			"Save")   queue_save ;;
          		esac
          	done
          }

          pick_playlist() {
          	_pls="$("''${MPC}" lsplaylists 2>/dev/null || true)"
          	[ -n "''${_pls:-}" ] || {
          		printf '%s\n' "No playlists found" | rofi_menu "Playlists"
          		return 1
          	}
          	_pl="$(printf '%s\n' "← Back" "''${_pls}" | rofi_menu "Playlists")" || return 1
          	[ "''${_pl}" = "← Back" ] && return 1
          	[ -n "''${_pl:-}" ] || return 1
          	printf '%s' "''${_pl}"
          }

          playlist_load_replace() {
          	_pl="$(pick_playlist || true)"
          	[ -n "''${_pl:-}" ] || return 0

          	_preview="$("''${MPC}" -f '%artist% — %title%' playlist "''${_pl}" 2>/dev/null || true)"

          	_confirm="$(printf '%s\n' "← Back" "Replace queue (confirm)" "''${_preview}" \
          		| rofi_menu "Load: ''${_pl}")" || return 0
          	[ "''${_confirm}" = "Replace queue (confirm)" ] || return 0

          	"''${MPC}" clear >/dev/null
          	"''${MPC}" load "''${_pl}" >/dev/null
          	"''${MPC}" play >/dev/null 2>&1 || true
          }

          playlist_append() {
          	_pl="$(pick_playlist || true)"
          	[ -n "''${_pl:-}" ] || return 0
          	"''${MPC}" load "''${_pl}" >/dev/null
          }

          playlist_delete() {
          	_pl="$(pick_playlist || true)"
          	[ -n "''${_pl:-}" ] || return 0
          	_confirm="$(printf '%s\n' "← Back" "Delete (confirm): ''${_pl}" \
          		| rofi_menu "Delete Playlist")" || return 0
          	[ "''${_confirm}" = "Delete (confirm): ''${_pl}" ] || return 0
          	"''${MPC}" rm "''${_pl}" >/dev/null
          }

          _get_playlist_dir() {
          	_pd="$(
          		"''${MPC}" config 2>/dev/null \
          			| "''${AWK}" -F' = ' '$1=="playlist_directory"{print $2; exit}' \
          			| tr -d '"'
          	)" || _pd=""
          	if [ -n "''${_pd:-}" ] && [ -d "''${_pd}" ]; then
          		printf '%s' "''${_pd}"
          		return 0
          	fi
          	# Common fallback locations
          	if [ -d "''${HOME}/.config/mpd/playlists" ]; then
          		printf '%s' "''${HOME}/.config/mpd/playlists"
          		return 0
          	fi
          	if [ -d "''${HOME}/.mpd/playlists" ]; then
          		printf '%s' "''${HOME}/.mpd/playlists"
          		return 0
          	fi
          	printf '%s' ""
          	return 1
          }

          playlist_add_current() {
          	_current_file="$("''${MPC}" -f '%file%' current 2>/dev/null || true)"
          	[ -n "''${_current_file:-}" ] || {
          		printf '%s\n' "Nothing is currently playing" | rofi_menu "Add to Playlist"
          		return 0
          	}
          	_current_pretty="$("''${MPC}" -f '%artist% — %title%' current 2>/dev/null || true)"
          	[ -n "''${_current_pretty:-}" ] || _current_pretty="''${_current_file}"

          	_existing="$("''${MPC}" lsplaylists 2>/dev/null || true)"
          	_choice="$(printf '%s\n' "← Back" "New playlist" "''${_existing}" \
          		| rofi_menu "Add: ''${_current_pretty}")" || return 0
          	[ "''${_choice}" = "← Back" ] && return 0
          	[ -n "''${_choice:-}" ] || return 0

          	if [ "''${_choice}" = "New playlist" ]; then
          		_pl="$(printf '%s' "" \
          			| "''${ROFI}" -dmenu -p "New playlist name" -i)" || return 0
          		[ -n "''${_pl:-}" ] || return 0
          	else
          		_pl="''${_choice}"
          	fi

          	"''${MPC}" addplaylist "''${_pl}" "''${_current_file}" >/dev/null || {
          		printf '%s\n' "Failed to add to ''${_pl}" | rofi_menu "Error" >/dev/null || true
          		return 0
          	}
          	printf '%s\n' "Added to ''${_pl} — press Enter" \
          		| rofi_menu "Add to Playlist" >/dev/null || true
          }

          playlist_remove_current() {
          	_current_file="$("''${MPC}" -f '%file%' current 2>/dev/null || true)"
          	[ -n "''${_current_file:-}" ] || {
          		printf '%s\n' "Nothing is currently playing" | rofi_menu "Remove from Playlist"
          		return 0
          	}
          	_current_pretty="$("''${MPC}" -f '%artist% — %title%' current 2>/dev/null || true)"
          	[ -n "''${_current_pretty:-}" ] || _current_pretty="''${_current_file}"

          	_existing="$("''${MPC}" lsplaylists 2>/dev/null || true)"
          	[ -n "''${_existing:-}" ] || {
          		printf '%s\n' "No playlists found" | rofi_menu "Remove from Playlist"
          		return 0
          	}

          	_pl="$(printf '%s\n' "← Back" "''${_existing}" \
          		| rofi_menu "Remove: ''${_current_pretty}")" || return 0
          	[ "''${_pl}" = "← Back" ] && return 0
          	[ -n "''${_pl:-}" ] || return 0

          	# Find all positions (1-based) of the current file in the playlist
          	_positions="$(
          		"''${MPC}" -f '%file%' playlist "''${_pl}" 2>/dev/null \
          			| "''${AWK}" -v target="''${_current_file}" \
          					'NR && $0==target { print NR }' \
          			| sort -rn
          	)" || _positions=""

          	[ -n "''${_positions:-}" ] || return 0

          	printf '%s\n' "''${_positions}" | while IFS= read -r _pos; do
          		[ -n "''${_pos:-}" ] && \
          			"''${MPC}" delplaylist "''${_pl}" "''${_pos}" >/dev/null
          	done
          }

          playlist_menu() {
          	while :; do
          		_choice="$(printf '%s\n' \
          			"← Back" \
          			"Load playlist (replace queue)" \
          			"Append playlist to queue" \
          			"Add current track to playlist" \
          			"Remove current track" \
          			"Delete playlist" \
          			| rofi_menu "Playlist")" || return 0
          		case "''${_choice}" in
          			"← Back")               return 0 ;;
          			"Load playlist (replace queue)") playlist_load_replace ;;
          			"Append playlist to queue")  playlist_append ;;
          			"Add current track to playlist")    playlist_add_current ;;
          			"Remove current track") playlist_remove_current ;;
          			"Delete playlist")      playlist_delete ;;
          		esac
          	done
          }

          search_add_any() {
          	_picks="$(
          		"''${MPC}" -f '%file%\t%artist% — %title%' search any "" 2>/dev/null \
          			| fmt_file_pretty \
          			| rofi_multi "Add (All)"
          	)" || return 0
          	printf '%s\n' "''${_picks}" | add_files_from_tablist
          }

          search_add_field_prompt() {
          	_field="''${1}"

          	# Pre-populate all unique values for the field so rofi can fuzzy filter them
          	_all_values="$("''${MPC}" list "''${_field}" 2>/dev/null || true)"
          	[ -n "''${_all_values:-}" ] || {
          		printf '%s\n' "No ''${_field} values found in library" | rofi_menu "''${_field}"
          		return 0
          	}

          	_query="$(printf '%s\n' "''${_all_values}" \
          		| rofi_menu "Search ''${_field}")" || return 0
          	[ -n "''${_query:-}" ] || return 0

          	_picks="$(
          		"''${MPC}" -f '%file%\t%artist% — %title%' search "''${_field}" "''${_query}" 2>/dev/null \
          			| fmt_file_pretty \
          			| rofi_multi "Add (''${_field}: ''${_query})"
          	)" || return 0
          	printf '%s\n' "''${_picks}" | add_files_from_tablist
          }

          search_add_genre() {
          	_genres="$("''${MPC}" list genre 2>/dev/null || true)"
          	[ -n "''${_genres:-}" ] || {
          		printf '%s\n' "No genres found" | rofi_menu "Genre"
          		return 0
          	}
          	_genre="$(printf '%s\n' "← Back" "''${_genres}" | rofi_menu "Genre")" || return 0
          	[ "''${_genre}" = "← Back" ] && return 0
          	_picks="$(
          		"''${MPC}" -f '%file%\t%artist% — %title%' search genre "''${_genre}" 2>/dev/null \
          			| fmt_file_pretty \
          			| rofi_multi "Add (Genre)"
          	)" || return 0
          	printf '%s\n' "''${_picks}" | add_files_from_tablist
          }

          get_music_dir() {
          	_md="$("''${MPC}" config 2>/dev/null \
          		| "''${AWK}" -F' = ' '$1=="music_directory"{print $2; exit}' \
          		| tr -d '"')" || _md=""
          	if [ -n "''${_md:-}" ] && [ -d "''${_md}" ]; then
          		printf '%s' "''${_md}"
          		return 0
          	fi
          	if [ -n "''${MPD_MUSIC_DIR:-}" ] && [ -d "''${MPD_MUSIC_DIR}" ]; then
          		printf '%s' "''${MPD_MUSIC_DIR}"
          		return 0
          	fi
          	if [ -d "''${HOME}/Music" ]; then
          		printf '%s' "''${HOME}/Music"
          		return 0
          	fi
          	printf '%s' ""
          	return 1
          }

          search_add_newest() {
          	_limit=500
          	_music_dir="$(get_music_dir || true)"
          	if [ -z "''${_music_dir:-}" ] || [ ! -d "''${_music_dir}" ]; then
          		printf '%s\n' "music_directory not found (set MPD_MUSIC_DIR?)" \
          			| rofi_menu "Newest"
          		return 0
          	fi
          	_newest="$(
          		"''${FIND}" "''${_music_dir}" -type f 2>/dev/null \
          			| while IFS= read -r _abs; do
          					_ts="$(stat -c %Y "''${_abs}" 2>/dev/null || printf '%s' "0")"
          					_rel="''${_abs#"''${_music_dir}"/}"
          					_base="''${_rel##*/}"
          					_base="''${_base%.*}"
          					printf '%s\t%s\t%s\n' "''${_ts}" "''${_rel}" "''${_base}"
          				done \
          			| sort -rn -k1,1 \
          			| head -n "''${_limit}"
          	)" || _newest=""
          	[ -n "''${_newest:-}" ] || {
          		printf '%s\n' "No files found" | rofi_menu "Newest"
          		return 0
          	}
          	_picks="$(
          		printf '%s\n' "''${_newest}" \
          			| "''${AWK}" -F'\t' '{ printf "%s\t%s\n", $2, $3 }' \
          			| rofi_multi "Add (Newest)"
          	)" || return 0
          	printf '%s\n' "''${_picks}" | add_files_from_tablist
          }

          search_rescan_db() {
          	_confirm="$(printf '%s\n' "← Back" "Rescan MPD database (confirm)" \
          		| rofi_menu "Rescan DB")" || return 0
          	[ "''${_confirm}" = "Rescan MPD database (confirm)" ] || return 0
          	if "''${MPC}" rescan >/dev/null 2>&1; then
          		:
          	else
          		"''${MPC}" update >/dev/null 2>&1 || true
          	fi
          	printf '%s\n' "Scan started (Go back)" | rofi_menu "MPD" >/dev/null || true
          }

          search_menu() {
          	while :; do
          		_choice="$(printf '%s\n' \
          			"← Back" \
          			"All (any)" \
          			"Artist (prompt)" \
          			"Genre (pick)" \
          			"Newest (file mtime)" \
          			"Title (prompt)" \
          			"Update DB (re-scan)" \
          			| rofi_menu "Search")" || return 0
          		case "''${_choice}" in
          			"← Back")              return 0 ;;
          			"All (any)")           search_add_any ;;
          			"Artist (prompt)")     search_add_field_prompt artist ;;
          			"Genre (pick)")        search_add_genre ;;
          			"Newest (file mtime)") search_add_newest ;;
          			"Title (prompt)")      search_add_field_prompt title ;;
          			"Update DB (re-scan)") search_rescan_db ;;
          		esac
          	done
          }

          top_menu() {
          	printf '%s\n' \
          		"Queue" \
          		"Playlist" \
          		"Search" \
          		"Close"
          }

          while :; do
          	_choice="$(top_menu | rofi_menu "MPD")" || exit 0
          	case "''${_choice}" in
          		"Queue")    queue_menu ;;
          		"Playlist") playlist_menu ;;
          		"Search")   search_menu ;;
          		"Close"|"") exit 0 ;;
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
            --arg tooltip "Current Track" \
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

    mpdArtWatch =
      pkgs.writeShellScriptBin "mpd-art-watch" # sh
        ''
          set -eu

          HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
          JQ="${pkgs.jq}/bin/jq"
          SWAYIMG="${pkgs.swayimg}/bin/swayimg"
          MPC="${pkgs.mpc}/bin/mpc"
          SLEEP="${pkgs.coreutils}/bin/sleep"
          DATE="${pkgs.coreutils}/bin/date"

          if [ -n "''${XDG_STATE_HOME:-}" ]; then
          	STATE_DIR="$XDG_STATE_HOME/mpd"
          else
          	STATE_DIR="$HOME/.local/state/mpd"
          fi
          mkdir -p "$STATE_DIR"
          COVER="$STATE_DIR/cover.jpg"
          LOG="$STATE_DIR/mpd-art-watch.log"

          log() { printf '[%s] %s\n' "$("$DATE" +'%F %T')" "$*" >>"$LOG"; }

          dump_cover() {
          	uri="$("$MPC" current -f %file% 2>/dev/null || true)"

          	# IMPORTANT: clear old cover so we never reuse stale art
          	rm -f "$COVER" 2>/dev/null || true

          	[ -n "''${uri:-}" ] || return 0

          	tmp="$STATE_DIR/cover.tmp"
          	if "$MPC" albumart "$uri" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
          		mv -f "$tmp" "$COVER"
          	else
          		rm -f "$tmp" 2>/dev/null || true
          		rm -f "$COVER" 2>/dev/null || true
          	fi
          }

          clients_json() { "$HYPRCTL" clients -j 2>/dev/null || printf '[]\n'; }

          addr_vis() {
          	clients_json | "$JQ" -r 'map(select(.class=="mpd-vis"))[0].address // empty'
          }

          art_addrs() {
          	clients_json | "$JQ" -r '.[] | select(.class=="mpd-art") | .address'
          }

          close_art_windows() {
          	art_addrs | while IFS= read -r a; do
          		[ -n "''${a:-}" ] || continue
          		"$HYPRCTL" dispatch closewindow "address:$a" >/dev/null 2>&1 || true
          	done
          }

          active_monitor() {
          	"$HYPRCTL" monitors -j 2>/dev/null \
          		| "$JQ" -r '.[] | select(.focused==true) | "\(.x) \(.width)"' \
          		| { read -r mx mw; printf '%s %s\n' "''${mx:-0}" "''${mw:-0}"; }
          }

          move_vis_for_state() {
          	# args: "with_art" | "no_art"
          	state="$1"

          	v="$(addr_vis || true)"
          	[ -n "''${v:-}" ] || return 0

          	set -- $(active_monitor)
          	mx="$1"
          	mw="$2"

          	# Y is constant in your rules
          	y=40

          	case "$state" in
          		with_art) dx=1175 ;;  # 900 + 260 + 15
          		no_art)   dx=915  ;;  # 900 + 15
          		*) return 0 ;;
          	esac

          	x=$(( mx + mw - dx ))
          	"$HYPRCTL" dispatch movewindowpixel "exact $x $y,address:$v" >/dev/null 2>&1 || true
          }

          last="$("$MPC" current -f %file% 2>/dev/null || true)"
          log "started (last=$last)"

          while :; do
          	# Wait briefly for mpd-vis to appear (avoid race)
          	tries=0
          	v="$(addr_vis || true)"
          	while [ -z "''${v:-}" ] && [ "$tries" -lt 10 ]; do
          		tries=$((tries + 1))
          		"$SLEEP" 0.2
          		v="$(addr_vis || true)"
          	done

          	if [ -z "''${v:-}" ]; then
          		log "mpd-vis not found after waiting; exiting"
          		exit 0
          	fi

          	cur="$("$MPC" current -f %file% 2>/dev/null || true)"
          	if [ -n "''${cur:-}" ] && [ "$cur" != "$last" ]; then
          		log "track changed: $last -> $cur"

          		# Always close existing art window(s) first, so stale art can't persist
          		close_art_windows

          		# Clear and attempt to dump new cover (your improved dump_cover that rm -f "$COVER" first)
          		dump_cover || true

          		# Relaunch only if new cover exists
          		if [ -s "$COVER" ]; then
          			"$SWAYIMG" --class mpd-art --scale fit -c info.show=no "$COVER" >/dev/null 2>&1 &
          			move_vis_for_state with_art
          		else
          			move_vis_for_state no_art
          		fi

          		last="$cur"
          	fi

          	"$SLEEP" 1
          done
        '';

    mpdVizArtPopout =
      pkgs.writeShellScriptBin "mpd-viz-art-popout" # sh
        ''
          set -eu

          HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
          JQ="${pkgs.jq}/bin/jq"
          ALACRITTY="${pkgs.alacritty}/bin/alacritty"
          CAVA="${pkgs.cava}/bin/cava"
          SWAYIMG="${pkgs.swayimg}/bin/swayimg"
          MPC="${pkgs.mpc}/bin/mpc"

          RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$UID}"
          PIDFILE="$RUNTIME_DIR/mpd-art-watch.pid"
          WATCH="${mpdArtWatch}/bin/mpd-art-watch"

          if [ -n "''${XDG_STATE_HOME:-}" ]; then
          	STATE_DIR="$XDG_STATE_HOME/mpd"
          else
          	STATE_DIR="$HOME/.local/state/mpd"
          fi
          mkdir -p "$STATE_DIR"
          COVER="$STATE_DIR/cover.jpg"

          dump_cover() {
          	uri="$("$MPC" current -f %file% 2>/dev/null || true)"
          	[ -n "''${uri:-}" ] || { rm -f "$COVER" 2>/dev/null || true; return 0; }

          	# IMPORTANT: clear old cover so we never reuse stale art
          	rm -f "$COVER" 2>/dev/null || true

          	tmp="$STATE_DIR/cover.tmp"
          	if "$MPC" albumart "$uri" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
          		mv -f "$tmp" "$COVER"
          	else
          		rm -f "$tmp" 2>/dev/null || true
          		# ensure cover stays absent when art isn't available
          		rm -f "$COVER" 2>/dev/null || true
          	fi
          }

          clients_json() {
          	"$HYPRCTL" clients -j 2>/dev/null || printf '[]\n'
          }

          addrs_by_class() {
          	cls_re="$1"
          	clients_json | "$JQ" -r --arg re "$cls_re" '.[] | select(.class|test($re)) | .address'
          }

          any_open() {
          	[ -n "$(addrs_by_class '^mpd-vis$' || true)" ] || [ -n "$(addrs_by_class '^mpd-art$' || true)" ]
          }

          close_by_addrs() {
          	while IFS= read -r addr; do
          		[ -n "''${addr:-}" ] || continue
          		"$HYPRCTL" dispatch closewindow "address:$addr" >/dev/null 2>&1 || true
          	done
          }

          stop_watcher() {
          	if [ -r "$PIDFILE" ]; then
          		pid="$(cat "$PIDFILE" 2>/dev/null || true)"
          		[ -n "''${pid:-}" ] && kill "$pid" >/dev/null 2>&1 || true
          		rm -f "$PIDFILE" >/dev/null 2>&1 || true
          	fi
          }

          start_watcher() {
          	# prevent duplicates
          	if [ -r "$PIDFILE" ]; then
          		oldpid="$(cat "$PIDFILE" 2>/dev/null || true)"
          		if [ -n "''${oldpid:-}" ] && kill -0 "$oldpid" >/dev/null 2>&1; then
          			return 0
          		fi
          	fi

          	"$WATCH" &
          	echo $! > "$PIDFILE"
          }

          close_all() {
          	addrs_by_class '^mpd-art$' | close_by_addrs
          	addrs_by_class '^mpd-vis$' | close_by_addrs
          	stop_watcher
          }

          launch_art() {
          	dump_cover || true
          	if [ -s "$COVER" ]; then
          		"$SWAYIMG" \
          			--class mpd-art \
          			--scale fit \
          			-c info.show=no \
          			"$COVER" >/dev/null 2>&1 &
          	fi
          }

          if any_open; then
          	close_all
          	exit 0
          fi

          "$ALACRITTY" --class mpd-vis,mpd-vis --title "MPD Visualizer" -e "$CAVA" >/dev/null 2>&1 &

          launch_art
          start_watcher

          exit 0
        '';
  };
in
{
  # Custom Nix snowflake info tooltip script
  nixVersions =
    pkgs.writeShellScriptBin "get-nix-versions" # sh
      ''
        set -eu
        kernelVer=""
        nixVer=""
        os_title=""

        kernelVer=$(uname -r)
        nixVer=$(nix --version)

        if [ -f "/etc/os-release" ]; then
        	_os=$(grep "^NAME=" </etc/os-release | cut -f2 -d= | tr -d '"')
        	_os_ver=$(grep "^VERSION=" </etc/os-release | cut -f2 -d= | tr -d '"')
        	os_title="$_os: $_os_ver"
        fi

        ${pkgs.jq}/bin/jq -c -n --arg os "$os_title" \
        --arg kernel "Kernel: $kernelVer" \
        --arg nix "$nixVer" \
        '{"tooltip": "\($os)\r\($kernel)\r\($nix)"}'
      '';

  calendarToggle =
    pkgs.writeShellScriptBin "calendar-toggle" # sh
      ''
        set -u

        NIX_HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
        NIX_JQ="${pkgs.jq}/bin/jq"
        NIX_KHAL="${pkgs.khal}/bin/khal"
        NIX_ALACRITTY="${pkgs.alacritty}/bin/alacritty"
        NIX_SLEEP="${pkgs.coreutils}/bin/sleep"

        WIN_WIDTH=1280
        WIN_HEIGHT=800
        WIN_Y=30
        WIN_CLASS="calendar-popup"

        # Check for existing calendar-popup window
        _addr="$(
          "''${NIX_HYPRCTL}" clients -j 2>/dev/null \
            | "''${NIX_JQ}" -r '
                map(select(.class == "calendar-popup"))[0].address // empty
              '
        )"

        if [ -n "''${_addr:-}" ]; then
          "''${NIX_HYPRCTL}" dispatch closewindow "address:''${_addr}" \
            >/dev/null 2>&1 || true
          exit 0
        fi

        # Get focused monitor width and x offset
        _monitor_info="$(
          "''${NIX_HYPRCTL}" monitors -j 2>/dev/null \
            | "''${NIX_JQ}" -r '.[] | select(.focused==true) | "\(.x) \(.width)"'
        )"
        _monitor_x="$(printf '%s' "''${_monitor_info}" | cut -d' ' -f1)"
        _monitor_width="$(printf '%s' "''${_monitor_info}" | cut -d' ' -f2)"

        # Calculate x to center popup under clock
        # Position left edge at monitor center minus half window width
        _x=$(( _monitor_x + (_monitor_width / 2) - (WIN_WIDTH / 2) ))

        # Launch calendar popup
        "''${NIX_ALACRITTY}" \
          --class "''${WIN_CLASS}" \
          --option "window.opacity=0.92" \
          -e "''${NIX_KHAL}" interactive \
          >/dev/null 2>&1 &

        # Wait for window to appear then position it
        _tries=0
        _new_addr=""
        while [ -z "''${_new_addr:-}" ] && [ "''${_tries}" -lt 10 ]; do
          _tries=$(( _tries + 1 ))
          "''${NIX_SLEEP}" 0.1
          _new_addr="$(
            "''${NIX_HYPRCTL}" clients -j 2>/dev/null \
              | "''${NIX_JQ}" -r '
                  map(select(.class == "calendar-popup"))[0].address // empty
                '
          )"
        done

        if [ -z "''${_new_addr:-}" ]; then
          printf "calendar-toggle: window did not appear\n" >&2
          exit 1
        fi

        "''${NIX_HYPRCTL}" dispatch movewindowpixel \
          "exact ''${_x} ''${WIN_Y},address:''${_new_addr}" \
          >/dev/null 2>&1 || true
      '';
}
// mpdScripts
