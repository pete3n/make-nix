#!/usr/bin/env sh

set -e

URL="$1"
EXPECTED_HASH="$2"

echo ">>> Verifying Nix installer integrity..."
curl -Ls "$URL" > scripts/nix_installer.sh
ACTUAL_HASH=$(cat scripts/nix_installer.sh | shasum | cut -d ' ' -f 1)

if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
  printf "\033[1;33mIntegrity check failed!\033[0m\n"
  printf 'Expected: %b' "$EXPECTED_HASH\n"
  printf 'Actual:   %b' "\033[0;31m$ACTUAL_HASH\033[0m\n"
	rm scripts/nix_installer.sh
  exit 1
fi

printf "\033[1;32m>>> Integrity check passed.\033[0m\n"
chmod +x scripts/nix_installer.sh
