#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -n "${KEEP_LOGS+x}" ]; then
	exit 0
fi

if [ -f "$MAKE_NIX_LOG" ]; then
	rm -f "$MAKE_NIX_LOG"
fi

if [ -f "$MAKE_NIX_ENV" ]; then
	rm -f "$MAKE_NIX_ENV"
fi

if [ -f "$MAKE_NIX_INSTALLER" ]; then
	rm -f "$MAKE_NIX_INSTALLER"
fi
