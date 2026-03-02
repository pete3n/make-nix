#!/usr/bin/env sh

# Print make help for ANSI and no ANSI terminals 

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: attrs.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

help_ansi="${script_dir}/help.txt"
help_no_ansi="${script_dir}/help_no_ansi.txt"
help_file=""
help_cmd=""

_supports_less_frx() {
  command -v less >/dev/null 2>&1 || return 1
  ESC_CHAR="$(printf '\033')"
  printf '\033[1;32mTEST\033[0m\n' | less -FRX 2>/dev/null | grep -q "$ESC_CHAR"
}

# Use NO_ANSI if set
if is_truthy "${NO_ANSI:-}" || "${NO_COLOR:-}"; then
  if has_cmd "less"; then
    help_cmd="less"
  elif has_cmd "cat"; then
    help_cmd="cat"
  else
    err 1 "Cannot display help; neither less nor cat are available in the PATH." >&2
  fi
  help_file="${help_no_ansi}"
else
  if _supports_less_frx; then
    help_cmd="less -FRX"
    help_file="${help_ansi}"
  else
    NO_ANSI="true"
    if has_cmd "less"; then
      help_cmd="less"
    elif has_cmd "cat"; then
      help_cmd="cat"
    else
      err 1 "Cannot display help; neither less nor cat are available in the PATH." >&2
    fi
    help_file="${help_no_ansi}"
  fi
fi

exec ${help_cmd} "${help_file}"
