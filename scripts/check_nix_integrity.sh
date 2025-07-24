#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

URL="$1"
EXPECTED_HASH="$2"

if [ "$DETERMINATE" = "1" ]; then
	printf "\n>>> Verifying Determinate Systems installer integrity...\n"
else
	printf "\n>>> Verifying Nix installer integrity...\n"
fi

curl -Ls "$URL" >scripts/nix_installer.sh
# shellcheck disable=SC2002
ACTUAL_HASH=$(cat scripts/nix_installer.sh | shasum | cut -d ' ' -f 1)

if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
	printf "%bIntegrity check failed!%b" "$YELLOW" "$RESET"
	printf "Expected: %b" "$EXPECTED_HASH\n"
	printf "Actual:   %b" "$RED$ACTUAL_HASH$RESET\n"
	rm scripts/nix_installer.sh
	exit 1
fi

printf "%b>>> Integrity check passed.%b\n" "$GREEN" "$RESET"
chmod +x scripts/nix_installer.sh
