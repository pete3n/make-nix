#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

host="${TGT_HOST:? error: host must be set.}"

@printf "Activating system config for Darwin..."
sudo ./result/sw/bin/darwin-rebuild switch --flake .#"$host}"
