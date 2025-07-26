#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"

if [ "${DETERMINATE:-0}" -eq 1 ]; then
	logf "\n%b>>> Verifying Determinate Systems installer integrity...%b\n" "$BLUE" "$RESET"
	URL=$DETERMINATE_INSTALL_URL
	EXPECTED_HASH=$DETERMINATE_INSTALL_HASH
else
	logf "\n%b>>> Verifying Nix installer integrity...%b\n" "$BLUE" "$RESET"
	URL=$NIX_INSTALL_URL
	EXPECTED_HASH=$NIX_INSTALL_HASH
fi

curl -Ls "$URL" >"$MAKE_NIX_INSTALLER"
# shellcheck disable=SC2002
ACTUAL_HASH=$(cat "$MAKE_NIX_INSTALLER" | shasum | cut -d ' ' -f 1)

if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
	logf "\n%bIntegrity check failed!%b\n" "$YELLOW" "$RESET"
	logf "Expected: %b" "$EXPECTED_HASH\n"
	logf "Actual:   %b" "$RED$ACTUAL_HASH$RESET\n"
	rm "$MAKE_NIX_INSTALLER"
	exit 1
fi

logf "\n%b>>> Integrity check passed.%b\n" "$GREEN" "$RESET"
chmod +x "$MAKE_NIX_INSTALLER"
