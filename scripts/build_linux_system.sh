#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

host="${BUILD_LINUX_HOST:? error: host must be set.}"

if [ -n "${DRY_RUN+x}" ]; then
	printf "\n%bDry-run%b %benabled%b, nothing will be built.\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
	printf "nix build --dry-run .#nixosConfigurations.%s.config.system.build.toplevel \
		--extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix build --dry-run .#nixosConfigurations.${host}.config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes'" "$LOG_PATH"
	else
		nix build --dry-run .#nixosConfigurations."${host}".config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes' | tee "$LOG_PATH"
	fi
else
	printf "\nBuilding system config for Linux...\n"
	printf "nix build .#nixosConfigurations.%s.config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes'" "${host}"
	if script -q -c true >/dev/null 2>&1; then
		script -q -c "nix build .#nixosConfigurations.${host}.config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes'" "$LOG_PATH"
	else
		nix build .#nixosConfigurations."${host}".config.system.build.toplevel \
			--extra-experimental-features 'nix-command flakes' | tee "$LOG_PATH"
	fi
fi
