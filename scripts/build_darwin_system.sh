#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

host="${TGT_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b, nothing will be built.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "nix build --dry-run .#darwinConfigurations.%s.system --extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true /dev/null; then
		script -q -c "nix build --dry-run .#darwinConfigurations.${host}.system \
			--extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
	else
		nix build --dry-run .#darwinConfigurations."${host}".system \
			--extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
	fi
else
	printf "\nBuilding system config for Darwin...\n"
	printf "nix build .#darwinConfigurations.%s.system \
			--extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true /dev/null; then
		script -q -c "nix build .#darwinConfigurations.${host}.system \
			--extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
	else
		nix build .#darwinConfigurations."${host}".system \
			--extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
	fi
fi
