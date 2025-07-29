#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

required_utils="cat chmod command curl cut dirname git grep mkdir printf \
	pwd rm shasum shift sudo read tee tr uname whoami xargs"
optional_utils="less script"

missing_required=false
missing_optional=false

for cmd in $required_utils; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		logf "%bMissing required dependency:%b %b%s%b\n" "$RED" "$RESET" "$CYAN" "$cmd" "$CYAN"
		missing_required=true
	fi
done

for cmd in $optional_utils; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
			logf "Missing optional dependency: %s\n" "$cmd"
			missing_optional=true
	fi
done

if [ "$missing_required" = false ]; then
	logf "%b✅%b All required dependencies are installed.\n" "$GREEN" "$RESET"
	if [ "$missing_optional" = true ]; then
			logf "%b⚠️%b  Some optional dependencies are missing.\n" "$YELLOW" "$RESET"
	fi
	exit 0
else
	logf "%b❌%b One or more required dependencies are missing.\n" "$RED" "$RESET"
	exit 1
fi
