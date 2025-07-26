#!/usr/bin/env sh
if [ -z "${_COMMON_SH_INCLUDED:-}" ]; then
	_COMMON_SH_INCLUDED=1

set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp is working and in your PATH.}"

# shellcheck disable=SC1090
. "$env_file"

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
		make clean
		cleaned=true
	fi
	exit "$status"
}

fi # _COMMON_SH_INCLUDED
