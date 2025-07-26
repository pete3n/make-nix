#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -z "${TGT_SYSTEM:-}" ]; then
  printf "%berror:%b Could not determine target system platform.\n" "$RED" "$RESET"
  exit 1
fi

if [ -z "${IS_LINUX:-}" ]; then
  printf "%berror:%b Could not determine if target system is Linux or Darwin.\n" "$RED" "$RESET"
  exit 1
fi

if [ "$IS_LINUX" = true ]; then
  exec scripts/build_linux_system.sh
else
  exec scripts/build_darwin_system.sh
fi
