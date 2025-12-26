#!/usr/bin/env sh

# Common helper functions for all scripts

# Prevent sourcing multiple times
if [ -z "${_common_sourced:-}" ]; then
	_common_sourced=1

	# Ensure MAKE_NIX_ENV was defined by make
	env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp is working and in your PATH.}"

	# shellcheck disable=SC1090
	. "${env_file}" || {
		printf "ERROR: common.sh failed to source MAKE_NIX_ENV file: %s" "${env_file}" >&2
		exit 1
	}

	# Error handler to provide ANSI colored message and call cleanup
	err() {
		_rc=${1:-1}
		shift || true

		_msg=$*

		# Print to stderr (render \n and any ANSI sequences included in _msg)
		if [ -n "${MAKE_NIX_LOG:-}" ]; then
			# Show on stderr, and append plain text to log
			printf "%b\n" "${C_ERR}error:${C_RST} ${_msg}" | tee -a "$MAKE_NIX_LOG" >&2
		else
			printf "%b\n" "${C_ERR}error:${C_RST} ${_msg}" >&2
		fi

		cleanup "${_rc}" "ERR"
		exit "${_rc}"
	}

	# Safely log to MAKE_NIX_LOG or print to stdout
	logf() {
		# shellcheck disable=SC2059
		if [ -n "${MAKE_NIX_LOG:-}" ]; then
			printf "$@" | tee -a "$MAKE_NIX_LOG"
		else
			printf "$@"
		fi
	}

	# Allow the user flexibility in setting boolean options
	# truthy=1,true,True,TRUE,yes,Yes,YES,on,On,ON,y,Y
	# Convention:
	# - quoted "true"/"false" are string values
	# - unquoted true/false are commands for control flow
	is_truthy() {
		case "${1:-}" in
		'1'|'true'|'True'|'TRUE'|'yes'|'Yes'|'YES'|'on'|'On'|'ON'|'y'|'Y') return 0 ;;
		*) return 1 ;;
		esac
	}

	# Ensure commands are present and are executable files.
	has_cmd() {
		_cmd_name="${1}"
		_cmd_path=$(command -v "${_cmd_name}" 2>/dev/null) || return 1
		[ -n "$_cmd_path" ] && [ -f "$_cmd_path" ] && [ -x "$_cmd_path" ]
	}

	# Prevent duplicate/unecessary sudo calls
	as_root() {
		if [ "$(id -u)" -eq 0 ]; then
			"$@"
		else
			sudo "$@"
		fi
	}

	_cleaned="false"
	# Cleanup temporary files
	cleanup() {
		[ "${_cleaned}" = "true" ] && return
		_cleaned="true"
		_script="${0##*/}" # Get the calling script basename, without requiring basename 
		_status="${1:-0}"
		_reason="${2:-EXIT}"

		printf '\n[cleanup] script=%s reason=%s exit_code=%s\n' \
			"${_script}" "${_reason}" "${_status}" >&2
		if ! is_truthy "${KEEP_LOGS:-}"; then
			_dir="${MAKE_NIX_TMPDIR:-}"
			if [ -n "${_dir}" ] && [ -d "${_dir}" ]; then
				# Prevent deleting root paths if $dir gets truncated somehow
				case "${_dir}" in 
					""|/|/tmp|/var/tmp) : ;; 
					*/make-nix.*) rm -rf "${_dir}" ;; 
					*) printf "common.sh [cleanup] failed to delete unexpected path: %s\n" "${_dir}" >&2 ;;
				esac
			fi
		fi

		# Prevent recursive calling of cleanup
		# Do not 'exit' on EXIT trap; only exit on INT/TERM so the script stops.
		[ "${_reason}" = "EXIT" ] || exit "${_status}"
	}

	# Check system for active nix-daemon 
	has_nix_daemon() {
		case "${UNAME_S}" in
		Darwin)
			as_root launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1
			;;
		Linux)
			if [ -x "$(command -v systemctl)" ] && [ -d /run/systemd/system ]; then
				systemctl is-active --quiet nix-daemon
			else
				# Fallback for non-systemd Linux
				pgrep -x nix-daemon >/dev/null 2>&1
			fi
			;;
		*)
			return 1
			;;
		esac
	}

	# Check system for active nix-daemon socket
	nix_daemon_socket_up() {
		[ -S /nix/var/nix/daemon-socket/socket ]
	}

	# Configure pathing for Nix/Nix-Daemon
	source_nix() {
		# Common locations across multi-user daemon installs and per-user installs
		for _file in \
			"$HOME/.nix-profile/etc/profile.d/nix.sh" \
			"$HOME/.nix-profile/etc/profile.d/nix-daemon.sh" \
			"/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
			"/nix/var/nix/profiles/default/etc/profile.d/nix.sh" \
			"/etc/profile.d/nix.sh" \
			"/etc/profile.d/nix-daemon.sh"
		do
			if [ -f "$_file" ]; then
				# shellcheck disable=SC1090
				. "$_file"
				# If it worked, nix should now resolve
				if command -v nix >/dev/null 2>&1; then
					return 0
				fi
			fi
		done

		# Fallback: directly add expected bin paths (helps right after install)
		for _bindir in \
			"/run/current-system/sw/bin" \
			"/nix/var/nix/profiles/default/bin" \
			"$HOME/.nix-profile/bin"
		do
			case ":$PATH:" in # Uniformly wrap paths in ::
				*":$_bindir:"*) : ;; # Don't duplicate path entries
				*) PATH="$_bindir:$PATH" ;;
			esac
		done
		export PATH

		command -v nix >/dev/null 2>&1
	}

	# Check for configuration tag match
	has_tag() {
		_tag="${1}"
		case ",${CFG_TAGS:-}," in
		*",${_tag},"*) return 0 ;;
		*) return 1 ;;
		esac
	}

	# Resolve the absolute path of any path
	resolve_path() {
		_path="${1}"
		_dir=$(cd "$(dirname "$_path")" 2>/dev/null && pwd) || return 1
		_filename=${_path##*/} # Resolve file name with basename
		printf '%s/%s\n' "${_dir}" "${_filename}"
	}

	# Determine if symlink is dead
	is_deadlink() {
		_path="${1}"
		if [ -L "${_path}" ] && [ ! -e "${_path}" ]; then
			return 0
		else
			return 1
		fi
	}
fi # _common_sourced
