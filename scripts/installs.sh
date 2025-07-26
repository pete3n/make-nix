#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

printf "installs: env file is: %s\n" "$MAKE_NIX_ENV"
printf "installs: calling check-dep\n"
make check-dependencies
printf "installs: calling os-check\n"
make installer-os-check
printf "installs: calling nix-integrity\n"
make check-nix-integrity
printf "installs: launching installers\n"
make launch-installers
