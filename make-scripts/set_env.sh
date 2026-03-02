#!/usr/bin/env sh
set -eu

# Allow the user flexibility in setting boolean options
# Convention:
# - quoted "true"/"false" are string values
# - unquoted true/false are commands for control flow
_is_truthy() {
	case "${1:-}" in
	'1'|'true'|'True'|'TRUE'|'yes'|'Yes'|'YES'|'on'|'On'|'ON'|'y'|'Y') return 0 ;;
	*) return 1 ;;
	esac
}

_env_file="${MAKE_NIX_ENV:?Environment file was not set! Ensure mktemp working and in your path.\n}"
if ! [ -f "${_env_file}" ]; then
	printf "error: Environment file %s could not be found!\n" "${_env_file}"
	exit 1
fi
# shellcheck disable=SC1090
. "${_env_file}"

if _is_truthy "${KEEP_LOGS:-}"; then
	printf "Logs will be preserved:\n%s\n%s\n%s\n" \
		"$MAKE_NIX_LOG" "$MAKE_NIX_ENV" "$MAKE_NIX_INSTALLER"
fi

# Avoid running twice if already marked initialized
if grep -q '^ENV_INITIALIZED=true$' "${_env_file}" 2>/dev/null; then
	exit 0
fi

# shellcheck disable=SC1091
make_env_file="make.env"
if [ ! -f "${make_env_file}" ]; then
	printf "error: make.env not found at %s\n" "${make_env_file}" >&2
	exit 1
fi

if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
	: # ANSI support is assumed
else
	NO_ANSI="true"
	printf "NO_ANSI=true\n" >> "${_env_file}"
fi

if _is_truthy "${NO_ANSI:-}" || _is_truthy "${NO_COLOR:-}"; then
	ansi_env="$(dirname "${0}")/no_ansi.env"
else
	ansi_env="$(dirname "${0}")/ansi.env"
fi

if [ ! -f "${ansi_env}" ]; then
	printf "error: environment file not found %s\n" "${ansi_env}" >&2
	exit 1
fi

if script -a -q -c true /dev/null 2>/dev/null; then
	USE_SCRIPT="true"
else
	USE_SCRIPT="false"
fi

{
	cat "${make_env_file}"
	cat "${ansi_env}"
	printf "USE_SCRIPT=%s\n" "${USE_SCRIPT}"

	# Semantic color definitions (write references, not expanded values)
	# shellcheck disable=SC2016
	printf 'C_CMD="%s"\n' '${BOLD}'
	# shellcheck disable=SC2016
	printf 'C_CFG="%s"\n' '${CYAN}'
	# shellcheck disable=SC2016
	printf 'C_ERR="%s"\n' '${RED}'
	# shellcheck disable=SC2016
	printf 'C_INFO="%s"\n' '${BLUE}'
	# shellcheck disable=SC2016
	printf 'C_OK="%s"\n'  '${GREEN}'
	# shellcheck disable=SC2016
	printf 'C_PATH="%s"\n' '${MAGENTA}'
	# shellcheck disable=SC2016
	printf 'C_RST="%s"\n' '${RESET}'
	# shellcheck disable=SC2016
	printf 'C_WARN="%s"\n' '${YELLOW}'

	printf "ENV_INITIALIZED=true\n"
} >> "${_env_file}"

if [ ! -f "${_env_file}" ]; then
	printf "error: writing environment file %s" "${_env_file}"
	exit 1
fi
