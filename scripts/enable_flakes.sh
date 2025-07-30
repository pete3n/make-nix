#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

nix_conf="$HOME/.config/nix/nix.conf"
features="experimental-features = nix-command flakes"

if [ -f "$nix_conf" ]; then
	if ! grep -qF "nix-command flakes" "$nix_conf"; then
		logf "\n%b>>> Enabling flakes...%b\n" "$BLUE" "$RESET"
		logf "\n%binfo:%b appending %s to %b%s%b\n" "$BLUE" "$RESET" "$features" \
			"$MAGENTA" "$nix_conf" "$RESET"
		printf "%s\n" "$features" >> "$nix_conf"
	fi
else
	logf "\n%b>>> Creating nix.conf with experimental features enabled...%b\n" "$BLUE" "$RESET"
	mkdir -p "$(dirname "$nix_conf")"
	printf "%s\n" "$features" > "$nix_conf"
fi
