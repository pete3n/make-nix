#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/installer.env"

if [ -f "$(dirname "$0")/nix_installer.sh" ]; then
	rm -f "$(dirname "$0")/nix_installer.sh"
fi

if [ -f "$LOG_PATH" ]; then
	rm -f "$LOG_PATH"
fi
