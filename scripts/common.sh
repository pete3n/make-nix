#!/usr/bin/env sh
if [ -z "${_COMMON_SH_INCLUDED:-}" ]; then
	_COMMON_SH_INCLUDED=1

	env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp is working and in your PATH.}"

	# shellcheck disable=SC1090
	. "$env_file" || {
		printf "ERROR: common.sh failed to source MAKE_NIX_ENV file: %s" "${env_file}" >&2
		exit 1
	}

	is_truthy() {
		var="${1:-}"

		case "$var" in
		1 | true | True | TRUE | yes | Yes | YES | on | On | ON | y | Y) return 0 ;;
		*) return 1 ;;
		esac
	}

	# shellcheck disable=SC2059
	logf() {
		if [ -n "${MAKE_NIX_LOG:-}" ]; then
			printf "$@" | tee -a "$MAKE_NIX_LOG"
		else
			printf "$@"
		fi
	}

	# as_root uses sudo unless already root
	as_root() {
		if [ "$(id -u)" -eq 0 ]; then
			"$@"
		else
			sudo "$@"
		fi
	}

	_cleaned=0
	cleanup() {
		[ "${_cleaned}" -eq 1 ] && return
		_cleaned=1
		_script="${0##*/}" # Get the calling script basename, without requiring basename 
		_status="${1:-0}"
		_reason="${2:-'EXIT'}"

		status=${1:-0}
		reason=${2:-EXIT}
		printf '\n[cleanup] script=%s reason=%s exit_code=%s\n' \
			"${_script}" "${_reason}" "${_status}" >&2
		if ! is_truthy "${KEEP_LOGS:-}"; then
			_dir="${MAKE_NIX_TMPDIR:-}"
			if [ -n "${_dir}" ] && [ -d "${_dir}" ]; then
				# Prevent deleting root paths if $dir gets truncated somehow
				case "${_dir}" in 
					""|/|/tmp|/var/tmp) : ;; 
					*/make-nix.*) rm -rf -- "$_dir" ;; 
				*) printf "common.sh [cleanup] failed to delete unexpected path: %s\n" "${_dir}" >&2 ;;
			esac
			fi
		fi

		# Do not 'exit' on EXIT trap; only exit on INT/TERM so the script stops.
		[ "${_reason}" = "EXIT" ] || exit "${_status}"
	}

	has_nix() {
		if [ -x "$(command -v nix)" ]; then
			return 0
		else
			return 1
		fi
	}

	has_nix_daemon() {
		case "$UNAME_S" in
		Darwin)
			sudo launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1
			;;
		Linux)
			if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
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

	nix_daemon_socket_up() {
		[ -S /nix/var/nix/daemon-socket/socket ]
	}

	has_nixos() {
		if command -v nixos-rebuild >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
	}

	has_nix_darwin() {
		[ "$UNAME_S" = "Darwin" ] || return 1
		# Activated system export OR tool still on PATH
		[ -x /run/current-system/sw/bin/darwin-rebuild ] || command -v darwin-rebuild >/dev/null 2>&1
	}

	source_nix() {
		for _file in \
			/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
			/nix/var/nix/profiles/default/etc/profile.d/nix.sh
		do
			if [ -f "${_file}" ]; then
				# shellcheck disable=SC1090
				. "${_file}"
				return 0
			fi
		done
		return 0
	}

	has_tag() {
		case ",$TGT_TAGS," in
		*",$1,"*) return 0 ;;
		*) return 1 ;;
		esac
	}

	resolve_path() {
		# $1 = file path (can be relative, with ../, etc.)
		_dir="$(cd "$(dirname "$1")" && pwd)"
		base="$(basename "$1")"
		printf '%s/%s\n' "$_dir" "$base"
	}

	is_deadlink() {
		if [ -L "$1" ] && [ ! -e "$1" ]; then
			return 0
		else
			return 1
		fi
	}
fi # _COMMON_SH_INCLUDED
