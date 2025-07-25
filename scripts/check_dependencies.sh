#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

required_utils="cat chmod command curl cut dirname git grep hostname mkdir printf rm \
	shasum sudo tee uname whoami"
optional_utils="less read script"

missing_required=0
missing_optional=0

for cmd in $required_utils; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		printf 'Missing required dependency: %s\n' "$cmd"
		missing_required=1
	fi
done

for cmd in $optional_utils; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
			printf 'Missing optional dependency: %s\n' "$cmd"
			missing_optional=1
	fi
done

if [ "$missing_required" -eq 0 ]; then
	printf "%b✅%b All required dependencies are installed.\n" "$GREEN" "$RESET"
	if [ "$missing_optional" -eq 1 ]; then
			printf '%b⚠️%b  Some optional dependencies are missing.\n' "$YELLOW" "$RESET"
	fi
	exit 0
else
	printf '%b❌%b One or more required dependencies are missing.\n' "$RED" "$RESET"
	exit 1
fi
