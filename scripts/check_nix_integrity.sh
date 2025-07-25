#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ "${DETERMINATE:-0}" -eq 1 ]; then
	printf "\n>>> Verifying Determinate Systems installer integrity...\n"
	URL=$DETERMINATE_INSTALL_URL
	EXPECTED_HASH=$DETERMINATE_INSTALL_HASH
else
	printf "\n>>> Verifying Nix installer integrity...\n"
	URL=$NIX_INSTALL_URL
	EXPECTED_HASH=$NIX_INSTALL_HASH
fi

curl -Ls "$URL" >"$MAKE_NIX_INSTALLER"
# shellcheck disable=SC2002
ACTUAL_HASH=$(cat "$MAKE_NIX_INSTALLER" | shasum | cut -d ' ' -f 1)

if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
	printf "%bIntegrity check failed!%b" "$YELLOW" "$RESET"
	printf "Expected: %b" "$EXPECTED_HASH\n"
	printf "Actual:   %b" "$RED$ACTUAL_HASH$RESET\n"
	rm "$MAKE_NIX_INSTALLER"
	exit 1
fi

printf "%b>>> Integrity check passed.%b\n" "$GREEN" "$RESET"
chmod +x "$MAKE_NIX_INSTALLER"
