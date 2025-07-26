#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

printf "\n>>> Lauching installer...\n"

install_flags=""
nix_found=0

if [ -n "${DETERMINATE+x}" ]; then
	install_flags="$DETERMINATE_INSTALL_MODE"
else
	if [ "${SINGLE_USER:-0}" -eq 1 ]; then
		install_flags="--no-daemon"
	else
		install_flags="$NIX_INSTALL_MODE"
	fi
fi

if nix --version >/dev/null 2>&1; then
	nix_found=1
fi

if [ "$nix_found" -eq 1 ]; then
	printf "%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	printf "If you want to re-install, please follow these instructions to uninstall first: \n"
	printf "%bhttps://nix.dev/manual/nix/latest/installation/uninstall.html%b\n" "$BLUE" "$RESET"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"
	else
		printf "%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
		exit 1
	fi
fi

if [ -n "${NIX_DARWIN+x}" ]; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		printf "\n>>> Installing nix-darwin...\n"
		sudo nix run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .
	else
		printf "%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi
