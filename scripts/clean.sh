#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

if is_truthy "${KEEP_LOGS:-}"; then
	exit 0
fi

if [ -e "${MAKE_NIX_LOG:-}" ]; then
	rm -f "$MAKE_NIX_LOG"
fi

if [ -e "${MAKE_NIX_ENV:-}" ]; then
	rm -f "$MAKE_NIX_ENV"
fi

if [ -e "${MAKE_NIX_INSTALLER:-}" ]; then
	rm -f "$MAKE_NIX_INSTALLER"
fi
