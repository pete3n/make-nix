#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

user="${TGT_USER:? error: user must be set.}"
host="${TGT_HOST:? error: host must be set.}"

printf "\nActivating home-manager configuration...\n"
printf "nix run nixpkgs#home-manager -- switch -b backup --flake .#%s@%s" "$user" "$host"
if script -q -c true /dev/null; then
	script -q -c "nix run nixpkgs#home-manager -- switch -b backup --flake .#${user}@${host}" "$MAKE_NIX_LOG"
else
	nix run nixpkgs#home-manager -- switch -b backup --flake ".#${user}@${host}" | tee "$MAKE_NIX_LOG"
fi
