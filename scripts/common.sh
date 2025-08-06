#!/usr/bin/env sh
set eux
if [ -z "${_COMMON_SH_INCLUDED:-}" ]; then
	_COMMON_SH_INCLUDED=1

	env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp is working and in your PATH.}"

	# shellcheck disable=SC1090
	. "$env_file"

	is_truthy() {
		var="${1:-}"

		case "$var" in
		1 | true | True | TRUE | yes | Yes | YES | on | On | ON | y | Y) return 0 ;;
		*) return 1 ;;
		esac
	}

	# shellcheck disable=SC2059
	logf() {
		printf "$@" | tee -a "$MAKE_NIX_LOG"
	}

	cleaned=false
	cleanup_on_halt() {
		$cleaned && return
		status=$1
		if [ "$status" -ne 0 ]; then
			logf "\nCleaning up...\n"
			SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
			# shellcheck disable=SC1091
			sh "$SCRIPT_DIR/clean.sh"
			cleaned=true
		fi
		exit "$status"
	}

	has_nix() {
		if command -v nix >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
	}

	source_nix() {
		if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
			# shellcheck disable=SC1091
			. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
		fi
	}

	has_nixos() {
		if command -v nixos-rebuild >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
	}

	has_nix_darwin() {
		if command -v darwin-rebuild >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
	}

fi # _COMMON_SH_INCLUDED
