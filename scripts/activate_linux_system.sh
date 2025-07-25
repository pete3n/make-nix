#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

host="${ACTIVATE_LINUX_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	@printf "\n%bDry-run%b %benabled%b: skipping system activiation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	exit 0
else
	@printf "Activating system config for Linux..."
	sudo ./result/sw/bin/nixos-rebuild switch --flake .#"${host}"
fi
