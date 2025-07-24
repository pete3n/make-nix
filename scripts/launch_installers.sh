#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

printf "\n>>> Installing Nix...\n"

if [ -n "${DETERMINATE:-}" ]; then
	INSTALL_FLAGS="install"
elif [ -n "${SINGLE_USER:-}" ]; then
	INSTALL_FLAGS="--no-daemon"
else
	INSTALL_FLAGS="--daemon"
fi

if [ -f "$(dirname "$0")/nix_installer.sh" ]; then
	sh "$(dirname "$0")/nix_installer.sh" $INSTALL_FLAGS
else
	printf "%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
	exit 1
fi

if [ -n "${NIX_DARWIN:-}" ]; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		printf "\n>>> Installing nix-darwin...\n"
		sudo nix run .#nix-darwin.darwin-rebuild -- switch
	else
		printf "%berror:%b Skipping nix-darwin install: macOS not detected.\n" "$RED" "$RESET"
		exit 1
	fi
fi
