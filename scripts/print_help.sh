#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

has_less() {
  command -v less >/dev/null 2>&1
}

has_cat() {
  command -v cat >/dev/null 2>&1
}

supports_less_frx() {
  command -v less >/dev/null 2>&1 || return 1
  ESC_CHAR="$(printf '\033')"
  printf '\033[1;32mTEST\033[0m\n' | less -FRX 2>/dev/null | grep -q "$ESC_CHAR"
}

help_dir="$(dirname "$0")"
help_ansi="${help_dir}/help.txt"
help_no_ansi="${help_dir}/help_no_ansi.txt"

# Use NO_ANSI if set
if is_truthy "${NO_ANSI:-}"; then
  if has_less; then
    help_cmd="less"
  elif has_cat; then
    help_cmd="cat"
  else
    printf "error: Cannot display help; neither less nor cat are available in the PATH.\n" >&2
    exit 1
  fi
  help_file="$help_no_ansi"
else
  if supports_less_frx; then
    help_cmd="less -FRX"
    help_file="$help_ansi"
  else
    NO_ANSI=true
    if has_less; then
      help_cmd="less"
    elif has_cat; then
      help_cmd="cat"
    else
      printf "error: Cannot display help; neither less nor cat are available in the PATH.\n" >&2
      exit 1
    fi
    help_file="$help_no_ansi"
  fi
fi

exec $help_cmd "$help_file"
