#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if grep -qE "path .+ does not exist" "${MAKE_NIX_LOG:-}" && [ -n "$(git diff-index HEAD)" ]; then
	printf "%b  ⚠️ warning: git tree is dirty!\n%b" "$YELLOW" "$RESET"
	printf "  If you see this error message:\n  '%berror:%b path %b/nix/store/...%b does not exist'\n\n" \
		"$RED" "$RESET" "$MAGENTA" "$RESET"
	printf "  Make sure all relevant files are tracked with Git using:\n"
	printf "  %bgit add%b <file>\n\n" "$RED" "$RESET"
	printf "  Check for changes with:\n"
	printf "  %bgit status%b\n\n" "$RED" "$RESET"
fi
