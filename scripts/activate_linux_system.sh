#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

host="${TGT_HOST:? error: host must be set.}"

printf "%b>>> Activating system config for Linux...%b" "$BLUE" "$RESET"
sudo ./result/sw/bin/nixos-rebuild switch --flake .#"${host}"
