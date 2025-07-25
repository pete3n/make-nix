#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

host="${ACTIVATE_DARWIN_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	@printf "\n%bDry-run%b %benabled%b: skipping system activiation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	exit 0
else
	@printf "Activating system config for Darwin..."
	sudo ./result/sw/bin/darwin-rebuild switch --flake .#"$host}"
fi
