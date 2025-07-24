#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

printf "\n>>> Lauching installer...\n"

INSTALL_FLAGS=""

if [ "${DETERMINATE:-0}" -eq 1 ]; then
  INSTALL_FLAGS="$DETERMINATE_INSTALL_MODE"
else
  if [ "${SINGLE_USER:-0}" -eq 1 ]; then
    INSTALL_FLAGS="--no-daemon"
  else
    INSTALL_FLAGS="$NIX_INSTALL_MODE"
  fi
fi

if [ -f "$(dirname "$0")/nix_installer.sh" ]; then
	sh "$(dirname "$0")/nix_installer.sh" "$INSTALL_FLAGS"
else
	printf "%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
	exit 1
fi

if [ "${NIX_DARWIN:-0}" -eq 1 ]; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		printf "\n>>> Installing nix-darwin...\n"
		sudo nix run .#nix-darwin.darwin-rebuild -- switch
	else
		printf "%berror:%b Skipping nix-darwin install: macOS not detected.\n" "$RED" "$RESET"
		exit 1
	fi
fi
