#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

logf "\n%bDEBUG:%b clean.sh called.\n" "$RED" "$RESET"
if is_truthy "${KEEP_LOGS:-}"; then
	exit 0
else
	cleanup 0 EXIT
fi
