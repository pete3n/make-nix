#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

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
	printf "%binfo:%b Nix found, installation skipped...\n" "$BLUE" "$RESET"
else
	if [ -f "$(dirname "$0")/nix_installer.sh" ]; then
		sh "$(dirname "$0")/nix_installer.sh" "$install_flags"
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
		printf "%berror:%b Skipping nix-darwin install: macOS not detected.\n" "$RED" "$RESET"
		exit 1
	fi
fi
