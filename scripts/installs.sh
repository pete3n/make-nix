#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

make check-dependencies
make installer-os-check
make check-nix-integrity
make launch-installers
