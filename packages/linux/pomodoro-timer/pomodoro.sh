#!/usr/bin/env bash

set -u

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/pomodoro/config.json"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro"
STATE_FILE="${STATE_DIR}/state.json"
SWAYIMG_PIDFILE="${STATE_DIR}/swayimg.pid"

config_get() {
  # Usage: config_get <jq_expression> [fallback]
  _val="$(jq -r "${1}" "${CONFIG_FILE}" 2>/dev/null || true)"
  if [ -z "${_val}" ] || [ "${_val}" = "null" ]; then
    printf '%s\n' "${2:-}"
  else
    printf '%s\n' "${_val}"
  fi
}

state_read() {
  # Usage: state_read <jq_expression> [fallback]
  _val="$(jq -r "${1}" "${STATE_FILE}" 2>/dev/null || true)"
  if [ -z "${_val}" ] || [ "${_val}" = "null" ]; then
    printf '%s\n' "${2:-}"
  else
    printf '%s\n' "${_val}"
  fi
}

state_write() {
  # Usage: state_write <json_string>
  mkdir -p "${STATE_DIR}"
  printf '%s\n' "${1}" > "${STATE_FILE}.tmp" \
    && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
}

state_update() {
  # Usage: state_update <jq_filter>
  # Updates existing state file in place using a jq filter
  _updated="$(jq "${1}" "${STATE_FILE}" 2>/dev/null || true)"
  if [ -n "${_updated}" ]; then
    printf '%s\n' "${_updated}" > "${STATE_FILE}.tmp" \
      && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  fi
}

get_interval_secs() {
  # Usage: get_interval_secs <mode> <index>
  # Returns interval in seconds for the given mode and index
  _mode="${1:-activity}"
  _idx="${2:-0}"

  if [ "${_mode}" = "activity" ]; then
    _key="activity_intervals"
  else
    _key="rest_intervals"
  fi

  _mins="$(jq -r \
    --arg key "${_key}" \
    --argjson idx "${_idx}" \
    '.[$key][$idx] // .[$key][0]' \
    "${CONFIG_FILE}" 2>/dev/null || printf '25')"

  printf '%s\n' $(( _mins * 60 ))
}

mpd_save_state() {
  _mpd_track="$(mpc -f '%file%' current 2>/dev/null || true)"
  _mpd_status_out="$(mpc status 2>/dev/null || true)"
  _mpd_status_line="$(printf '%s\n' "${_mpd_status_out}" | sed -n '2p')"

  _elapsed_raw="$(printf '%s\n' "${_mpd_status_line}" \
    | sed -n 's/.*[[:space:]]\([0-9]*\):\([0-9]*\)\/[0-9]*:[0-9]*.*/\1 \2/p')"
	_mpd_mins="$(printf '%s\n' "${_elapsed_raw}" | cut -d' ' -f1)"
	_mpd_secs="$(printf '%s\n' "${_elapsed_raw}" | cut -d' ' -f2)"
	# Strip leading zeros to prevent octal interpretation
	_mpd_secs="$(printf '%s' "${_mpd_secs}" | sed 's/^0*//')"
	_mpd_secs="${_mpd_secs:-0}"
	_mpd_elapsed=$(( ${_mpd_mins:-0} * 60 + _mpd_secs ))

  case "${_mpd_status_line}" in
    "[playing]"*) _mpd_status="playing" ;;
    "[paused]"*)  _mpd_status="paused"  ;;
    *)            _mpd_status="stopped" ;;
  esac

  printf '%s\n' "${_mpd_track:-}"
  printf '%s\n' "${_mpd_elapsed}"
  printf '%s\n' "${_mpd_status}"
}

mpd_restore_state() {
  _track="${1:-}"
  _elapsed="${2:-0}"
  _status="${3:-stopped}"

  mpc clear 2>/dev/null || true
  if [ -n "${_track}" ]; then
    mpc add "${_track}" 2>/dev/null || true
    mpc play 1 2>/dev/null || true
    if [ "${_elapsed}" -gt 0 ]; then
      mpc seek "${_elapsed}" 2>/dev/null || true
    fi
  fi
  case "${_status}" in
    "paused")  mpc pause 2>/dev/null || true ;;
    "stopped") mpc stop  2>/dev/null || true ;;
  esac
}

# Display an image with class pomodoro-img sourced from either a image
# filepath or a randomly selected image in a directory path.
show_image() {
  _image_path="${1:-}"
  _image=""
  _duration=""

  if [ -z "${_image_path}" ] || [ ! -e "${_image_path}" ]; then
    return 0
  fi

  if [ -d "${_image_path}" ]; then
    _image="$(find "${_image_path}" \
      -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' \
         -o -iname '*.png' -o -iname '*.webp' \) \
      | shuf -n1)"
  else
    _image="${_image_path}"
  fi

  if [ -z "${_image}" ]; then
    return 0
  fi

  _duration="$(config_get '.image_display_duration' '5')"

  swayimg --class pomodoro-img --scale fit -c info.show=no "${_image}" &
  _swayimg_pid=$!
  printf '%s\n' "${_swayimg_pid}" > "${SWAYIMG_PIDFILE}"

  # Block here for the full duration keeping the transition process
  # and its lock file alive until the image is done
  sleep "${_duration}"
  kill "${_swayimg_pid}" 2>/dev/null || true
  rm -f "${SWAYIMG_PIDFILE}"
}

close_image() {
  if [ -r "${SWAYIMG_PIDFILE}" ]; then
    _pid="$(cat "${SWAYIMG_PIDFILE}" 2>/dev/null || true)"
    if [ -n "${_pid}" ]; then
      kill "${_pid}" 2>/dev/null || true
    fi
    rm -f "${SWAYIMG_PIDFILE}"
  fi
}

cmd_transition() {
  _expected_mode="${1:-}"
  _expected_id="${2:-0}"
  _lock_pid=""
  _mode=""
  _transition_id=""
  _activity_idx=""
  _rest_idx=""
  _activity_playlist=""
  _rest_playlist=""
  _rest_image=""
  _activity_image=""
  _duration=""
  _resume_track=""
  _resume_elapsed="0"
  _image_path=""
  _next_playlist=""
  _current_track=""
  _current_elapsed_raw=""
  _current_mins=""
  _current_secs=""
  _current_elapsed=0

  if [ ! -r "${STATE_FILE}" ]; then
    return 0
  fi

  _mode="$(state_read '.mode' 'activity')"
  _transition_id="$(state_read '.transition_id' '0')"

  # Verify mode matches
  if [ -n "${_expected_mode}" ] && [ "${_mode}" != "${_expected_mode}" ]; then
    return 0
  fi

  # Verify transition ID matches - prevents duplicate transitions
  if [ "${_transition_id}" != "${_expected_id}" ]; then
    return 0
  fi

  # Consume the transition ID immediately to prevent any duplicate
	state_update '.transition_id = 0'

  _activity_idx="$(state_read '.activity_idx' '0')"
  _rest_idx="$(state_read '.rest_idx' '0')"
  _activity_playlist="$(config_get '.activity_playlist' '')"
  _rest_playlist="$(config_get '.rest_playlist' '')"
  _rest_image="$(config_get '.rest_image' '')"
  _activity_image="$(config_get '.activity_image' '')"
  _duration="$(config_get '.image_display_duration' '5')"

  # Save current MPD position BEFORE switching playlist
  _current_track="$(mpc -f '%file%' current 2>/dev/null || true)"
  _current_elapsed_raw="$(mpc status 2>/dev/null \
    | sed -n 's/.*[[:space:]]\([0-9]*\):\([0-9]*\)\/[0-9]*:[0-9]*.*/\1 \2/p')"
	_current_mins="$(printf '%s\n' "${_current_elapsed_raw}" | cut -d' ' -f1)"
	_current_secs="$(printf '%s\n' "${_current_elapsed_raw}" | cut -d' ' -f2)"
	# Strip leading zeros to prevent octal interpretation
	_current_secs="$(printf '%s' "${_current_secs}" | sed 's/^0*//')"
	_current_secs="${_current_secs:-0}"
	_current_elapsed=$(( ${_current_mins:-0} * 60 + _current_secs ))

  if [ "${_mode}" = "rest" ]; then
    _next_playlist="${_rest_playlist}"
    _image_path="${_rest_image}"
    _resume_track="$(state_read '.rest.track' '')"
    _resume_elapsed="$(state_read '.rest.elapsed' '0')"
    state_update \
      ".activity.track = \"${_current_track}\" | .activity.elapsed = ${_current_elapsed}"
  else
    _next_playlist="${_activity_playlist}"
    _image_path="${_activity_image}"
    _resume_track="$(state_read '.activity.track' '')"
    _resume_elapsed="$(state_read '.activity.elapsed' '0')"
    state_update \
      ".rest.track = \"${_current_track}\" | .rest.elapsed = ${_current_elapsed}"
  fi

	# Switch MPD playlist
	mpc clear 2>/dev/null || true
	mpc load "${_next_playlist}" 2>/dev/null || true

	if [ -n "${_resume_track}" ]; then
		mpc searchadd filename "${_resume_track}" 2>/dev/null || true
		mpc play 1 2>/dev/null || true
		if [ "${_resume_elapsed}" -gt 0 ]; then
			mpc seek "${_resume_elapsed}" 2>/dev/null || true
		fi
	else
		mpc play 2>/dev/null || true
	fi

	mpc repeat on 2>/dev/null || true

  show_image "${_image_path}"
}

cmd_ticker() {
  mkdir -p "${STATE_DIR}"

  _default_name="$(config_get '.default_activity_name' 'Activity')"
  _clock_text="$(date +'%H:%M')"
  _default_text="$(printf '<span color="#7ebae4">   </span>%s' "${_clock_text}")"

  if [ ! -r "${STATE_FILE}" ]; then
    jq -cn \
      --arg text "${_default_text}" \
      --arg class "clock" \
      '{text:$text,tooltip:"",class:$class}'
    return 0
  fi

  _status="$(state_read '.status' 'stopped')"
  _mode="$(state_read '.mode' 'activity')"
  _remaining="$(state_read '.remaining' '0')"
  _activity_name="$(state_read '.activity_name' "${_default_name}")"

  if [ "${_status}" != "running" ]; then
    jq -cn \
      --arg text "${_default_text}" \
      --arg class "clock" \
      '{text:$text,tooltip:"",class:$class}'
    return 0
  fi

  _remaining=$(( _remaining - 1 ))

	if [ "${_remaining}" -le 0 ]; then
		_activity_idx="$(state_read '.activity_idx' '0')"
		_rest_idx="$(state_read '.rest_idx' '0')"

		if [ "${_mode}" = "activity" ]; then
			_next_mode="rest"
			_next_secs="$(get_interval_secs rest "${_rest_idx}")"
			_next_label="Rest"
			_next_class="rest"
		else
			_next_mode="activity"
			_next_secs="$(get_interval_secs activity "${_activity_idx}")"
			_next_label="${_activity_name}"
			_next_class="activity"
		fi

		# Generate unique transition ID using current timestamp
		_transition_id="$(date +%s%N)"

		# Write new state with transition ID
		_new_state="$(jq \
			--arg mode "${_next_mode}" \
			--argjson remaining "${_next_secs}" \
			--arg transition_id "${_transition_id}" \
			'.mode = $mode | .remaining = $remaining | .transition_id = $transition_id' \
			"${STATE_FILE}")"
		state_write "${_new_state}"

		# Output new mode display
		_next_mins=$(( _next_secs / 60 ))
		jq -cn \
			--arg text "${_next_label}: ${_next_mins}:00" \
			--arg class "${_next_class}" \
			'{text:$text,tooltip:"",class:$class}'

		exec 1>/dev/null

		(
			setsid env \
				XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" \
				XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" \
				pomodoro transition "${_next_mode}" "${_transition_id}" &
		) &
		disown $!
		return 0
	fi

  # Only update the remaining field, preserve everything else
  state_update ".remaining = ${_remaining}"

  _mins=$(( _remaining / 60 ))
  _secs=$(( _remaining % 60 ))
  _countdown="$(printf '%d:%02d' "${_mins}" "${_secs}")"

  if [ "${_mode}" = "activity" ]; then
    _label="${_activity_name}"
    _class="activity"
  else
    _label="Rest"
    _class="rest"
  fi

  jq -cn \
    --arg text "${_label}: ${_countdown}" \
    --arg class "${_class}" \
    '{text:$text,tooltip:"",class:$class}'
}

case "${1:-ticker}" in
  ticker)      cmd_ticker                    ;;
  transition)  cmd_transition "${2:-}" "${3:-0}" ;;
  close-image) close_image                   ;;
  *)
    printf 'Usage: pomodoro <ticker|transition|close-image>\n' >&2
    exit 1
    ;;
esac
