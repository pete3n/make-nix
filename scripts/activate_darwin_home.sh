#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

: "${LOG_PATH:-"/tmp/make-nix.out"}"

if [ "${DRY_RUN:-0}" -eq 1 ]; then
	printf "\n%bDry-run%b %benabled%b: skipping home activiation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
else
	printf "\nSwitching home-manager configuration...\n"
	printf "nix run nixpkgs#home-manager -- switch -b backup --flake .#%s@%s" "$USER" "$HOST"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix run nixpkgs#home-manager -- switch -b backup --flake .#${USER}@${HOST}" "$LOG_PATH"
	else
		nix run nixpkgs#home-manager -- switch -b backup --flake ".#${USER}@${HOST}" | tee "$LOG_PATH"
	fi
fi
