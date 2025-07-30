#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

if has_nixos; then
	printf "%binfo:%b NixOS is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

if has_darwin; then
	printf "%binfo:%b Nix-Darwin is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

if [ "${UNAME_S:-}" != "Linux" ] && [ "${UNAME_S:-}" != "Darwin" ]; then
		printf "%binfo%b: unsupported OS: %s\n" "$BLUE" "$RESET" "${UNAME_S:-}"
		exit 1
fi

sh "$SCRIPT_DIR/check_deps.sh"
sh "$SCRIPT_DIR/check_installer_integrity.sh"
sh "$SCRIPT_DIR/launch_installers.sh"
