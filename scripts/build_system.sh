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
  exec BUILD_LINUX_HOST="$BUILD_HOST" ./build_linux_system.sh
else
  exec BUILD_DARWIN_HOST="$BUILD_HOST" ./build_darwin_system.sh
fi
