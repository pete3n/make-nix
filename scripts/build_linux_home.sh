#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"
# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

user=$BUILD_LINUX_USER
host=$BUILD_LINUX_HOST

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b: configuration will not be activated.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "Building home-manager config for Linux...\n"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --dry-run --flake .#${user}@${host}" "$LOG_PATH"
	else
		nix run nixpkgs#home-manager -- build -b backup --dry-run --flake ".#${user}@${host}" | tee "$LOG_PATH"
	fi
else
	printf "Building home-manager configuration for Linux...\n"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix run nixpkgs#home-manager -- build -b backup --flake .#${user}@${host}" "$LOG_PATH"
	else
		nix run nixpkgs#home-manager -- build -b backup --flake ".#${user}@${host}" | tee "$LOG_PATH"
	fi
fi
