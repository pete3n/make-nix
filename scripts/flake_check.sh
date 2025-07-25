#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

if script -q -c true /dev/null; then
	script -q -c "nix flake check --all-systems --extra-experimental-features 'nix-command flakes'" "$LOG_PATH"
else
	nix flake check --all-systems --extra-experimental-features 'nix-command flakes' | tee "$LOG_PATH"
fi
