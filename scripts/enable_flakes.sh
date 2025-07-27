#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

nix_conf="$HOME/.config/nix/nix.conf"
features="experimental-features = nix-command flakes"

if [ -f "$nix_conf" ]; then
	if ! grep -qF "nix-command flakes" "$nix_conf"; then
		logf "\n%b>>> Appending '%s' to %s %b\n" "$BLUE" "$features" "$nix_conf" "$RESET"
		printf "%s\n" "$features" >> "$nix_conf"
	fi
else
	logf "\n%bCreating nix.conf with experimental features enabled...%b\n" "$BLUE" "$RESET"
	mkdir -p "$(dirname "$nix_conf")"
	printf "%s\n" "$features" > "$nix_conf"
fi
