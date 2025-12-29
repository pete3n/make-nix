#!/usr/bin/env sh

# Manual clean script.

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

if is_truthy "${KEEP_LOGS:-}"; then
	exit 0
else
	cleanup 0 "CLEAN"
fi
