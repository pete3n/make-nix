#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

printf "installs: env file is: %s" "$MAKE_NIX_ENV"
make check-dependencies
make installer-os-check
make check-nix-integrity
make launch-installers
