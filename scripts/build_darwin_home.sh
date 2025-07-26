#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

user="${TGT_USER:? error: user must be set.}"
host="${TGT_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b: configuration will not be activated.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "\n%b>>>%b Building home-manager configuration for Darwin...\n" "$BLUE" "$RESET"
	if script -q -c true /dev/null; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --dry-run --flake .#${user}@${host}" "$MAKE_NIX_LOG"
	else
		nix run nixpkgs#home-manager -- build -b backup --dry-run --flake ".#${user}@${host}" | tee "$MAKE_NIX_LOG"
	fi
else
	printf "Building home-manager configuration for Darwin...\n"
	if script -q -c true /dev/null; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --flake .#${user}@${host}" "$MAKE_NIX_LOG"
	else
		nix run nixpkgs#home-manager -- build -b backup --flake ".#${user}@${host}" | tee "$MAKE_NIX_LOG"
	fi
fi
