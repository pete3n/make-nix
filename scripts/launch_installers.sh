#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"

logf "\n%b>>> Launching installer...%b\n" "$BLUE" "$RESET"

install_flags=""
if [ -n "${DETERMINATE+x}" ]; then
	install_flags="$DETERMINATE_INSTALL_MODE"
else
	if [ "${SINGLE_USER:-0}" -eq 1 ]; then
		install_flags="--no-daemon"
	else
		install_flags="$NIX_INSTALL_MODE"
	fi
fi

if command -v nix >/dev/null 2>&1; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	logf "If you want to re-install, please follow these instructions to uninstall first: \n"
	logf "%bhttps://nix.dev/manual/nix/latest/installation/uninstall.html%b\n" "$BLUE" "$RESET"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"
	else
		logf "\n%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
		exit 1
	fi
fi

if [ -n "${NIX_DARWIN+x}" ]; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		logf "\n%b>>> Installing nix-darwin...%b\n" "$BLUE" "$RESET"
		check_for_nix
		make write-build-target
		sudo nix run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .
	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi

if [ "${UNAME_S:-}" = "Linux" ] && [ -n "${NIXGL+x}" ]; then
	logf "\n%b>>> Installing NixGL...%b\n" "$BLUE" "$RESET"
fi
