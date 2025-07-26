#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

if ! [ -f "$env_file" ]; then
	printf "error: Environment file %s could not be found!\n" "$env_file"
fi

# shellcheck disable=SC1090
. "$env_file"

if [ -n "${KEEP_LOGS+x}" ]; then
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
	printf '\033[1;34mANSI colors supported.\033[0m\n'
else
	printf "ANSI colors not supported.\n"
	printf "NO_ANSI=true\n" >>"$env_file"
fi

if [ ${NO_ANSI+x} ]; then
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
