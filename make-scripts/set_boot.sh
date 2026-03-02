#!/usr/bin/env sh

# Set boot specialisation options
# TODO: Fix not incrementing build number
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: uninstalls.sh failed to source common.sh from %s\n" \
	"${script_dir}/installs.sh" >&2
	exit 1
}

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

boot_spec=""

# Find newest boot entry filename for a given specialisation.
# Echoes just the filename (not a path), or empty if none found.
_latest_specialisation_conf() {
	_spec=$1
	_dir=/boot/loader/entries
	_prefix='nixos-generation-'
	_suffix="-specialisation-${_spec}.conf"

	_tmp=$(mktemp) || return 1
	# Best-effort cleanup even if caller forgets
	trap 'rm -f "$_tmp"' HUP INT TERM QUIT

	# Let root do the matching inside find (no shell globbing before sudo)
	# Suppress find errors; we only care if we got any paths.
	as_root find "$_dir" -maxdepth 1 -type f -name "${_prefix}*${_suffix}" -print >"$_tmp" 2>/dev/null || :

	_best_gen=
	_best_file=

	# If file is empty -> no match
	while IFS= read -r _path; do
		_base=${_path##*/}                 # filename
		_rest=${_base#"${_prefix}"}       # gen-specialisation-specname.conf
		_gen=${_rest%%-*}            # generation

		case $_gen in
			''|*[!0-9]*) continue ;;
		esac

		if [ -z "${_best_gen}" ] || [ "$_gen" -gt "$_best_gen" ]; then
			_best_gen=$_gen
			_best_file=$_base
		fi
	done <"$_tmp"

	rm -f "$_tmp"
	trap - HUP INT TERM QUIT

	printf '%s' "${_best_file}"
}

# SPECS: comma-separated list, e.g. "x11,wayland,x11_egpu"
# BOOT_SPEC:
#   - if truthy => use first spec from SPECS
#   - else if non-empty => must match one of SPECS
#   - else => do nothing
_set_boot_spec() {
	_boot_spec_in=${BOOT_SPEC:-}

	# Normalize SPECS into one-per-line, trimmed, drop empties
	_specs_nl=$(
		printf '%s' "${SPECS:-}" |
		tr ',' '\n' |
		sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
	)

	if [ -z "$_specs_nl" ]; then
		logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "${C_INFO}" "${C_RST}"
		exit 0
	fi

	# Truthy => take first
	if is_truthy "$_boot_spec_in"; then
		_first_spec=$(printf '%s\n' "$_specs_nl" | sed -n '1p')
		boot_spec=$_first_spec
		return 0
	fi

	if [ -z "$_boot_spec_in" ]; then
		logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "${C_INFO}" "${C_RST}"
		exit 0
	fi

	# Trim BOOT_SPEC for comparison
	_boot_spec_in=$(printf '%s' "$_boot_spec_in" | xargs)

	# Validate membership
	if printf '%s\n' "$_specs_nl" | grep -Fx -- "$_boot_spec_in" >/dev/null 2>&1; then
		boot_spec=$_boot_spec_in
		return 0
	fi

	# Not valid => discard with warning
	logf "\n%bwarn:%b BOOT_SPEC '%s' not in available SPECS (%s). Ignoring.\n" \
		"${C_WARN}" "${C_RST}" "$_boot_spec_in" "${SPECS:-}"
	boot_spec=
	return 1
}

_set_boot() {
	if is_truthy "${DRY_RUN:-}"; then
		logf "\n%bDry run, skipping setting boot specialisation.%b\n" \
		"${C_INFO}" "${C_RST}"
		exit 0
	fi

	logf "\n%b>>> Attempting to set default boot option for specialisation:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_INFO}" "${boot_spec}" "${C_RST}"

	_default_conf="$(
		as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
			head -n1 |
			cut -d' ' -f2- ||
			true
	)"

	if [ -z "${_default_conf}" ]; then
		err 1 "No default boot entry found in ${C_PATH}/boot/loader/loader.conf${C_RST}"
	fi

	_special_conf=$(_latest_specialisation_conf "${boot_spec}")

	if [ -z "${_special_conf}" ]; then
		logf "%b⚠️warning:%b no boot entries found for specialisation: %s\n" \
			"${C_WARN}" "${C_RST}" "${boot_spec}"
		exit 0
	fi

	if [ "${_default_conf}" = "${_special_conf}" ]; then
		logf "%binfo:%b Default boot entry %balready set%b to newest %bspecialisation:%b %s\n" \
			"${C_INFO}" "${C_RST}" "${C_OK}" "${C_RST}" "${C_INFO}" "${C_RST}" "${_default_conf}"
		exit 0
	fi

	if as_root test -f "/boot/loader/entries/${_special_conf}"; then
		logf "Found /boot/loader/entries/%s\n" "${_special_conf}"
		logf "Backing up /boot/loader/loader.conf ...\n"
		as_root cp /boot/loader/loader.conf /boot/loader/loader.backup
		logf "Setting default boot to %s\n" "${_special_conf}"
		as_root sed -i "s|^default .*|default ${_special_conf}|" /boot/loader/loader.conf

		_new_default="$(
			as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
				head -n1 |
				cut -d' ' -f2- ||
				true
		)"

		if [ "${_new_default}" = "${_special_conf}" ]; then
			logf "%b✔ success:%b default boot set to: %b%s%b\n" "${C_OK}" "${C_RST}" \
				"${C_PATH}" "${_special_conf}" "${C_RST}"
			exit 0
		else
			logf "%b✖ error:%b failed to update default boot entry. Current setting: %s\n" \
				"${C_ERR}" "${C_RST}" "$_new_default"
			logf "Reverting changes to backup...\n"
			if as_root cp /boot/loader/loader.backup /boot/loader/loader.conf; then
				logf "%b✔ success:%b backup restored.\n" "${C_OK}" "${C_RST}"
			else
				_msg="%berror:%b failed to restore backup. Please perform manual restore of"
				_msg="${_msg} /boot/loader/loader.conf\n"
				logf "${_msg}" "${C_ERR}" "${C_RST}"
			fi
			exit 1
		fi
	else
		logf "%b⚠️warning:%b specialisation config not found: /boot/loader/entries/%s\n" \
			"${C_WARN}" "${C_RST}" "$_special_conf"
		exit 0
	fi
}

if [ -z "${BOOT_SPEC:-}" ] && [ -z "${SPECS:-}" ]; then
	logf "\n%binfo:%b No specialisations provided. Boot menu will not be modified.\n" \
	"${C_INFO}" "${C_RST}"
	exit 0
else
	_set_boot_spec
	_set_boot
fi
