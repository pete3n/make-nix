#!/usr/bin/env sh
set -eu

is_truthy() {
	var="${1:-}"

	case "$var" in
	1 | true | True | TRUE | yes | Yes | YES | on | On | ON | y | Y) return 0 ;;
	*) return 1 ;;
	esac
}

env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

if ! [ -f "$env_file" ]; then
	printf "error: Environment file %s could not be found!\n" "$env_file"
fi

# shellcheck disable=SC1090
. "$env_file"

if is_truthy "${KEEP_LOGS:-}"; then
	printf "Logs will be preserved:\n%s\n%s\n%s\n" \
		"$MAKE_NIX_LOG" "$MAKE_NIX_ENV" "$MAKE_NIX_INSTALLER"
fi

# Avoid running twice if already marked initialized
if grep -q '^ENV_INITIALIZED=true$' "$env_file" 2>/dev/null; then
	exit 0
fi

# shellcheck disable=SC1091
installer_env="installer.env"
if [ ! -f "$installer_env" ]; then
	printf "error: installer.env not found at %s\n" "$installer_env" >&2
	exit 1
fi

if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
	: # ANSI support is assumed
else
	printf "NO_ANSI=true\n" >>"$env_file"
fi

if is_truthy "${NO_ANSI:-}"; then
	ansi_env="$(dirname "$0")/no_ansi.env"
else
	ansi_env="$(dirname "$0")/ansi.env"
fi

if [ ! -f "$ansi_env" ]; then
	printf "error: environment file not found %s\n" "$ansi_env" >&2
	exit 1
fi

if script -a -q -c true /dev/null 2>/dev/null; then
	USE_SCRIPT=true
else
	USE_SCRIPT=false
fi

{
	cat "$installer_env"
	cat "$ansi_env"
	printf "USE_SCRIPT=%s\n" "$USE_SCRIPT"
	printf "ENV_INITIALIZED=true\n"
} >>"$env_file"

if [ ! -f "$env_file" ]; then
	printf "error: writing environment file %s" "$env_file"
	exit 1
fi
