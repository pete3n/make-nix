#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -z "${system:-}" ]; then
  printf "%berror:%b Could not determine target system platform.\n" "$RED" "$RESET"
  exit 1
fi

if [ -z "${is_linux:-}" ]; then
  printf "%berror:%b Could not determine if target system is Linux or Darwin.\n" "$RED" "$RESET"
  exit 1
fi

if [ "$is_linux" = true ]; then
  exec ACTIVATE_LINUX_HOST="$ACTIVATE_HOST" ./activate_linux_system.sh
else
  exec ACTIVATE_DARWIN_HOST="$ACTIVATE_HOST" ./activate_darwin_system.sh
fi
