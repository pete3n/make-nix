#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

: "${LOG_PATH:="/tmp/make-nix.out"}"
: "${DRY_RUN:=0}"

if [ "${DRY_RUN}" -eq 1 ]; then
	printf "\n%bDry-run%b %benabled%b: configuration will not be activated.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "Building home-manager config for Darwin...\n"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --dry-run --flake .#${USER}@${HOST}" "$LOG_PATH"
	else
		nix run nixpkgs#home-manager -- build -b backup --dry-run --flake ".#${USER}@${HOST}" | tee "$LOG_PATH"
	fi
else
	printf "Building home-manager configuration for Darwin...\n"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --flake .#${USER}@${HOST}" "$LOG_PATH"
	else
		nix run nixpkgs#home-manager -- build -b backup --flake ".#${USER}@${HOST}" | tee "$LOG_PATH"
	fi
fi
