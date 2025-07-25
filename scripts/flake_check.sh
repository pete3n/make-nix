#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if script -q -c true /dev/null; then
	script -q -c "nix flake check --all-systems --extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
else
	nix flake check --all-systems --extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
fi
