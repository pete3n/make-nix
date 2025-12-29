#!/usr/bin/env sh

# Provide custom warning for Nix build failures if the Git tree is dirty.
# Because the default Nix error is a confusing and unhelpful "file not found"

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	logf "ERROR: check_dirty_warn.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

if grep -qE "path .+ does not exist" "${MAKE_NIX_LOG:-}" && \
	[ -n "$(git diff-index HEAD)" ]; then
	logf "%b  ⚠️ warning: git tree is dirty!\n%b" "${C_WARN}" "${C_RST}"
	logf "  If you see this error message:\n  '%berror:%b path %b/nix/store/...%b does not exist'\n\n" \
		"${C_ERR}" "${C_RST}" "${C_PATH}" "${C_RST}"
	logf "  Make sure all relevant files are tracked with Git using:\n"
	logf "  %bgit add%b <file>\n\n" "${C_ERR}" "${C_RST}"
	logf "  Check for changes with:\n"
	logf "  %bgit status%b\n\n" "${C_ERR}" "${C_RST}"
fi
