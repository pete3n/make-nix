#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

has_cmd() {
  search_path="$PATH"

  case ":$search_path:" in *":/sbin:"*) : ;;        *) search_path="$search_path:/sbin" ;; esac
  case ":$search_path:" in *":/usr/sbin:"*) : ;;    *) search_path="$search_path:/usr/sbin" ;; esac
  case ":$search_path:" in *":/usr/local/sbin:"*) : ;; *) search_path="$search_path:/usr/local/sbin" ;; esac

  ( PATH="$search_path"; command -v -- "$1" >/dev/null 2>&1 )
}


# Dependency groups
common_deps="cat dirname grep pgrep printf pwd rm tee"
install_deps="chmod curl cut hostname mkdir shasum"
if [ "${UNAME_S:-}" = "Linux" ]; then 
	uninstall_deps="cp cmp diff grep groupdel read rm sed seq sudo tee userdel"
else
	uninstall_deps="cp cat cmp diff grep dscl launchctl read rm sed sudo tee"
fi
config_common_deps="git hostname uname whoami"
config_system_deps="sudo"

spec_boot_opt_deps="cut xargs"
set_spec_boot_opt_deps="sudo"
use_cache_opt_deps="cut mkdir read sudo"
nix_darwin_opt_deps="sudo"

optional_utils="less script"

TARGETS="$1"

required_utils="$common_deps"

for target in $TARGETS; do
  case "$target" in
		install)
      required_utils="$required_utils $install_deps"
      ;;
		uninstall)
			required_utils="$required_utils $uninstall_deps"
			;;
    home|system|all)
      required_utils="$required_utils $config_common_deps"
      [ "$target" = "system" ] && required_utils="$required_utils $config_system_deps"
      ;;
  esac
done

# Add option-based dependencies
[ -n "${TGT_SPEC:-}" ]       && required_utils="$required_utils $spec_boot_opt_deps"
is_truthy "${BOOT_SPEC:-}"   && required_utils="$required_utils $set_spec_boot_opt_deps"
is_truthy "${USE_CACHE:-}"   && required_utils="$required_utils $use_cache_opt_deps"
is_truthy "${NIX_DARWIN:-}"  && required_utils="$required_utils $nix_darwin_opt_deps"

# Remove duplicates
deduped_utils=""
for cmd in $required_utils; do
  case " $deduped_utils " in
    *" $cmd "*) : ;; # already included
    *) deduped_utils="$deduped_utils $cmd" ;;
  esac
done
required_utils="$deduped_utils"

missing_required=false
missing_optional=false

for cmd in $required_utils; do
  if ! has_cmd "$cmd"; then
    logf "\n%berror:%b missing required dependency: %b%s%b\n" "$RED" "$RESET" "$RED" "$cmd" "$RESET"
    missing_required=true
  fi
done

# Check optional utilities
for cmd in $optional_utils; do
  if ! has_cmd "$cmd"; then
    logf "\n%binfo:%b missing optional dependency: %s\n" "$BLUE" "$RESET" "$cmd"
    missing_optional=true
  fi
done

# Final output
if [ "$missing_required" = false ]; then
  logf "\n%b✅%b All required dependencies are installed.\n" "$GREEN" "$RESET"
  [ "$missing_optional" = true ] && logf "%b⚠️%b  Some optional dependencies are missing.\n" "$YELLOW" "$RESET"
  exit 0
else
  logf "\n%b❌%b One or more required dependencies are missing.\n" "$RED" "$RESET"
  exit 1
fi
