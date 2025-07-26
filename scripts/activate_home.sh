#!/usr/bin/env sh
set -eu

env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b: skipping home activiation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	exit 0
fi

if [ -z "${TGT_SYSTEM:-}" ]; then
  printf "%berror:%b Could not determine target system platform.\n" "$RED" "$RESET"
  exit 1
fi

if [ -z "${IS_LINUX:-}" ]; then
  printf "%berror:%b Could not determine if target system is Linux or Darwin.\n" "$RED" "$RESET"
  exit 1
fi

if [ "$IS_LINUX" = true ]; then
  exec scripts/activate_linux_home.sh
else
  exec scripts/activate_darwin_home.sh
fi
