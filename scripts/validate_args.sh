#!/usr/bin/env sh

# Validate make arguments and env vars

set -eu
script_dir="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: validate_args.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

for _bool in \
	USE_KEYS USE_CACHE USE_DETERMINATE USE_HOMEBREW INSTALL_DARWIN \
	DRY_RUN HOME_ALONE NO_ANSI SINGLE_USER KEEP_LOGS BOOT_SPEC; do

  eval "_val=\${${_bool}-__UNSET__}"

  # Truly unset → fine
  [ "${_val}" = "__UNSET__" ] && continue

  # Set but empty → error
  if [ -z "${_val}" ]; then
    err 1 "${_bool} was provided but was empty. Expected: true/false, yes/no, on/off, 1/0"
  fi

  if ! is_truthy "${_val}" && ! is_falsey "${_val}"; then
		_msg="Invalid boolean value for ${_bool}: ${_val}\n"
    printf "\n%s %s %s Expected one of: true/false, yes/no, on/off, 1/0\n"\
			"${_msg}" "${_bool}" "${_val}"
		exit 1
  fi
done

# TODO: New targets
# all (install, check, build, activate)
# home, system, both 
# check
# build 
# activate
# rebuild

