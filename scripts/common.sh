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

	cleaned="false"
	# Cleanup temporary files
	cleanup() {
		[ "${cleaned}" = "true" ] && return 0
		cleaned="true"

		_script="${0##*/}" # Get the calling script basename, without requiring basename 
		_status="${1:-0}"
		_reason="${2:-EXIT}"

		_cleanup_dir() {
			_dir="${1}"

			rm -rf -- "${_dir}" 2>/dev/null && return 0

			printf "%s\n" "warning: failed to remove temp dir: ${_dir}" >&2
			return 0
		}

		{ printf '\n[cleanup] called by %s with reason=%s and exit code=%s\n' \
			"${_script}" "${_reason}" "${_status}" >&2; } || : 

		if ! is_truthy "${KEEP_LOGS:-}"; then
			_dir="${MAKE_NIX_TMPDIR:-}"
			if [ -n "${_dir}" ] && [ -d "${_dir}" ]; then
				# Prevent deleting root paths if $dir gets truncated somehow
				case "${_dir}" in 
					""|/|/tmp|/var/tmp) : ;; 
					*/make-nix.*) _cleanup_dir "${_dir}" ;; 
					*) { printf "common.sh [cleanup] failed to delete unexpected path: %s\n" \
							"${_dir}" >&2; 
						} || : ;;
				esac
			fi
		fi

		# Prevent recursive calling of cleanup
		# Do not 'exit' on EXIT trap. Only exit on signals.
		[ "${_reason}" = "EXIT" ] || exit "${_status}"
	}

	# Error handler to provide ANSI colored messages (if enabled) and cleanup
	err() {
		_rc=${1:-1}
		shift || true

		_msg="$*"
		_c_err=${C_ERR-}
		_c_rst=${C_RST-}

		# Log if possible (defensively with nop to avoid set -e exit)
		if [ -n "${MAKE_NIX_LOG:-}" ]; then
			{ printf "%b\n" "${_c_err}error:${_c_rst} ${_msg}" | tee -a "$MAKE_NIX_LOG" >&2; } || :
		else
			{ printf "%b\n" "${_c_err}error:${_c_rst} ${_msg}" >&2; } || :
		fi

		cleanup "${_rc}" "ERR" || :
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

	is_falsey() {
		case "${1:-}" in
		'0'|'false'|'False'|'FALSE'|'no'|'No'|'NO'|'off'|'Off'|'OFF'|'n'|'N') return 0 ;;
		*) return 1 ;;
		esac
	}

	# Ensure commands are present and are executable files.
	has_cmd() {
		_cmd_name=${1:?}

		if _cmd_path=$(command -v -- "$_cmd_name" 2>/dev/null); then
			# command -v can return non-path strings in some cases (shell builtins/functions).
			# If it looks like a path, require it to be an executable file.
			case "$_cmd_path" in
				/*) [ -f "$_cmd_path" ] && [ -x "$_cmd_path" ] ;;
				*) return 1 ;;
			esac
		else
			return 1
		fi
	}

	# Print a command (argv) with ANSI coloring.
	# - Everything prints in C_CMD
	# - The last arg (or a chosen arg) prints in C_CFG
	# Usage:
	#   print_cmd "$@"                 # highlight last arg
	#   print_cmd --idx N -- "$@"      # highlight argv[N] (1-based)
	print_cmd() {
		_idx=""

		if [ "${1:-}" = "--idx" ]; then
			_idx="${2:-}"
			shift 2 || true
		fi

		[ "${1:-}" = "--" ] && shift || true

		_argc=$#

		# Guard against unset or non-numeric index
		case "${_idx:-}" in
			''|*[!0-9]*) _idx="${_argc}" ;;
		esac

		logf "%b" "${C_CMD}"

		_i=1
		for _arg in "$@"; do
			if [ "${_i}" -eq "${_idx}" ]; then
				logf "%b%s%b " "${C_CFG}" "${_arg}" "${C_CMD}"
			else
				logf "%s " "${_arg}"
			fi
			_i=$((_i + 1))
		done

		logf "%b\n" "${C_RST}"
	}

	# Prevent duplicate/unecessary sudo calls
	as_root() {
		if [ "$(id -u)" -eq 0 ]; then
			"$@"
		else
			sudo "$@"
		fi
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

	# Attempt to source the nix binary
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
				break # Only source the first match
			fi
		done

		# Fallback: directly add expected bin paths
		for _bindir in \
			"/run/current-system/sw/bin" \
			"/nix/var/nix/profiles/default/bin" \
			"$HOME/.nix-profile/bin"
		do
			if [ -x "${_bindir}/nix" ]; then
				case ":$PATH:" in
					*":$_bindir:"*) : ;;
					*) PATH="$_bindir:$PATH" ;;
				esac
			fi
		done
		export PATH
		return 0
	}

	# Attempt to source the darwin-rebuild 
	source_darwin() {
		_bindir="/run/current-system/sw/bin"

		# If nix-darwin isn't present, do nothing (do NOT fail under set -e)
		if [ -d "${_bindir}" ] && { [ -x "${_bindir}/darwin-rebuild" ] || [ -x "${_bindir}/darwin-uninstaller" ]; }; then
			case ":$PATH:" in
				*":${_bindir}:"*) : ;;
				*) PATH="${_bindir}:$PATH" ;;
			esac
			export PATH
		fi

		return 0
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
