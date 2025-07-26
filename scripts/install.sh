#!/usr/bin/env sh
set -eu

make init-env
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

# Cleanup handler
cleanup() {
    printf "%b→%b Running cleanup..." "${GREEN}" "${RESET}"
    make clean || printf "%b⚠️%b Cleanup failed!" "${RED}" "${RESET}"
}

trap cleanup EXIT

make check-dependencies
make installer-os-check
make check-nix-integrity
make launch-installers
