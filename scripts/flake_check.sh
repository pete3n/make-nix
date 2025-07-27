#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

: "${USE_SCRIPT:=false}"

if [ "${USE_SCRIPT:-}" = "true" ]; then
	script -a -q -c "nix flake check --all-systems --extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
else
	nix flake check --all-systems --extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
fi
