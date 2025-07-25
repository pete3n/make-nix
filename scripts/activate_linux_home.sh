#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

user="${ACTIVATE_LINUX_USER:? error: user must be set.}"
host="${ACTIVATE_LINUX_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b: skipping home activiation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	exit 0
else
	printf "\nActivating home-manager configuration...\n"
	printf "nix run nixpkgs#home-manager -- switch -b backup --flake .#%s@%s" "$user" "$host"
	if script -q -c true /dev/null; then
		script -q -c "nix run nixpkgs#home-manager -- switch -b backup --flake .#${user}@${host}" "$MAKE_NIX_LOG"
	else
		nix run nixpkgs#home-manager -- switch -b backup --flake ".#${user}@${host}" | tee "$MAKE_NIX_LOG"
	fi
fi
