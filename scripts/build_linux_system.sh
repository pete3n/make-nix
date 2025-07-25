#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

host="${BUILD_LINUX_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b, nothing will be built.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "nix build --dry-run .#nixosConfigurations.%s.config.system.build.toplevel --extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true /dev/null; then
		script -q -c "nix build --dry-run .#nixosConfigurations.${host}.config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
	else
		nix build --dry-run .#nixosConfigurations."${host}".config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
	fi
else
	printf "\nBuilding system config for Linux...\n"
	printf "nix build .#nixosConfigurations.%s.config.system.build.toplevel --extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true /dev/null; then
		script -q -c "nix build .#nixosConfigurations.${host}.config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes'" "$MAKE_NIX_LOG"
	else
		nix build .#nixosConfigurations."${host}".config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes' | tee "$MAKE_NIX_LOG"
	fi
fi
