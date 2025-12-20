#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

if is_truthy "${KEEP_LOGS:-}"; then
	exit 0
else
	cleanup 0 EXIT
fi
