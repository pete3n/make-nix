#!/usr/bin/env sh
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

	_CLEANED=0

	cleanup_on_halt() {
		[ "${_CLEANED}" -eq 1 ] && return
		_CLEANED=1

		status=${1:-$?}

		if [ "$status" -ne 0 ]; then
			logf "\n%b>>> Cleaning up...%b\n" "$BLUE" "$RESET"
		fi

		# Keep logs and exit with original status for debug
		if is_truthy "${KEEP_LOGS:-}"; then
			exit "$status"
		fi

		rm_if_set() {
			eval 'file="$'"$1"'"'
			if [ -n "${file:-}" ] && [ -e "$file" ]; then
				rm -f -- "$file" || true
				eval "$1=''"
			fi
		}

		rm_if_set MAKE_NIX_LOG
		rm_if_set MAKE_NIX_ENV
		rm_if_set MAKE_NIX_INSTALLER

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

	has_goal() {
		case " $MAKE_GOALS " in
		*" $1 "*) return 0 ;;
		*) return 1 ;;
		esac
	}

	has_tag() {
		case ",$TGT_TAGS," in
		*",$1,"*) return 0 ;;
		*) return 1 ;;
		esac
	}

	resolve_path() {
		# $1 = file path (can be relative, with ../, etc.)
		dir="$(cd "$(dirname -- "$1")" && pwd)"
		base="$(basename -- "$1")"
		printf '%s/%s\n' "$dir" "$base"
	}
fi # _COMMON_SH_INCLUDED
