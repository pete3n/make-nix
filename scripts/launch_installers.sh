#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

logf "\n%b>>> Launching installer...%b\n" "$BLUE" "$RESET"

install_flags=""
if is_truthy "${DETERMINATE:-}"; then
	install_flags="$DETERMINATE_INSTALL_MODE"
else
	if is_truthy "${SINGLE_USER:-}"; then
		install_flags="--no-daemon"
	else
		install_flags="$NIX_INSTALL_MODE"
	fi
fi

if command -v nix >/dev/null 2>&1; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	logf "If you want to re-install, please uninstall first.\n"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"
	else
		logf "\n%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
		exit 1
	fi
fi

sh "$SCRIPT_DIR/enable_flakes.sh"
sh "$SCRIPT_DIR/set_subs_keys.sh"

if is_truthy "${NIX_DARWIN:-}"; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		logf "\n%b>>> Installing nix-darwin...%b\n" "$BLUE" "$RESET"
		check_for_nix exit
		sh "$SCRIPT_DIR/install_nix_darwin.sh"
	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi
