#!/usr/bin/env sh

# Check the dependencies exist for a make goal

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: check_deps.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

_has_cmd_any() { command -v "$1" >/dev/null 2>&1; }

# Dependency groups
common_deps="cat dirname grep pgrep printf pwd rm tee"
install_deps="chmod curl cut mkdir sed shasum tr"
if [ "${UNAME_S:-}" = "Linux" ]; then 
	uninstall_deps="awk cp cmp diff groupdel rm sed seq sudo tee userdel"
else
	uninstall_deps="cp cat cmp diff dscl launchctl rm sed sudo tee"
fi
config_common_deps="git uname whoami"
config_system_deps="sudo"
spec_boot_opt_deps="cut xargs"
set_spec_boot_opt_deps="sudo"
use_cache_opt_deps="cut mkdir sudo"
nix_darwin_opt_deps="sudo"
optional_utils="less script"

TARGETS=${*:-}

required_utils="${common_deps}"

for target in $TARGETS; do
  case "${target}" in
		install)
      required_utils="${required_utils} ${install_deps}"
      ;;
		uninstall)
			required_utils="${required_utils} ${uninstall_deps}"
			;;
    home|system|all)
      required_utils="${required_utils} ${config_common_deps}"
      [ "${target}" = "system" ] && required_utils="${required_utils} ${config_system_deps}"
      ;;
  esac
done

# Add option-based dependencies
[ -n "${SPECS:-}" ] && required_utils="${required_utils} ${spec_boot_opt_deps}"
if is_truthy "${BOOT_SPEC:-}"; then
  required_utils="${required_utils} ${set_spec_boot_opt_deps}"
fi
if is_truthy "${USE_CACHE:-}"; then
  required_utils="${required_utils} ${use_cache_opt_deps}"
fi
if is_truthy "${INSTALL_DARWIN:-}"; then
  required_utils="${required_utils} ${nix_darwin_opt_deps}"
fi

# Remove duplicates
deduped_utils=""
for cmd in ${required_utils}; do
  case " ${deduped_utils} " in
    *" ${cmd} "*) : ;; # already included
    *) deduped_utils="${deduped_utils} ${cmd}" ;;
  esac
done
required_utils="${deduped_utils}"

missing_required="false"
missing_optional="false"

# Required dependencies
for cmd in ${required_utils}; do
  if ! _has_cmd_any "${cmd}"; then
		logf "\n%berror:%b missing required dependency: %b%s%b\n" \
			"${C_ERR}" "${C_RST}" "${C_ERR}" "${cmd}" "${C_RST}"
    missing_required="true"
  fi
done

# Optional dependencies
for cmd in ${optional_utils}; do
  if ! _has_cmd_any "${cmd}"; then
    logf "\n%binfo:%b missing optional dependency: %s\n" "${C_INFO}" "${C_RST}" "${cmd}"
    missing_optional="true"
  fi
done

# Aggregate dependency results
if [ "${missing_required}" = "false" ]; then
  logf "\n%b✅%b All required dependencies are installed.\n" "${C_OK}" "${C_RST}"
  [ "${missing_optional}" = "true" ] && \
		logf "%b⚠️%b  Some optional dependencies are missing.\n" "${C_WARN}" "${C_RST}"
  exit 0
else
  err 1 "One or more required dependencies are missing."
fi
