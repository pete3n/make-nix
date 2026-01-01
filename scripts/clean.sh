#!/usr/bin/env sh

# Manual clean script.

set -eu

_is_truthy() {
	case "${1:-}" in
	'1'|'true'|'True'|'TRUE'|'yes'|'Yes'|'YES'|'on'|'On'|'ON'|'y'|'Y') return 0 ;;
	*) return 1 ;;
	esac
}

if _is_truthy "${KEEP_LOGS:-}"; then
  exit 0
fi

# Only delete paths that match your safety pattern
dir="${MAKE_NIX_TMPDIR:-}"
if [ -n "$dir" ] && [ -d "$dir" ]; then
  case "$dir" in
    ""|/|/tmp|/var/tmp) : ;;
    */make-nix.*) rm -rf -- "$dir" ;;
    *) printf "clean-sh: refusing to delete unexpected path: %s\n" "$dir" >&2 ;;
  esac
fi
