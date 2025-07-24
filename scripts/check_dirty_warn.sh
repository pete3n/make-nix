#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

log_file=/tmp/make-nix.out
if grep -qE "path .+ does not exist" "$log_file" && [ -n "$(git diff-index HEAD)" ]; then
	printf "%b  ⚠️ Warning: git tree is dirty!\n%b" "$YELLOW" "$RESET"
	printf "  If you see this error message:\n  '%berror:%b path %b/nix/store/...%b does not exist'\n\n" \
		"$RED" "$RESET" "$MAGENTA" "$RESET"
	printf "  Make sure all relevant files are tracked with Git using:\n"
	printf "  %bgit add%b <file>\n\n" "$RED" "$RESET"
	printf "  Check for changes with:\n"
	printf "  %bgit status%b\n\n" "$RED" "$RESET"
fi
