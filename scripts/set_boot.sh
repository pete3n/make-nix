#!/usr/bin/env sh

# Set a boot specialisation as the default boot option
# TODO: If specialisations are defined, then default to setting boot
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: uninstalls.sh failed to source common.sh from %s\n" \
	"${script_dir}/installs.sh" >&2
	exit 1
}

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

first_spec=""

if ! is_truthy "${BOOT_SPEC:-}" || is_truthy "${DRY_RUN:-}"; then
	exit 0
fi

if [ -z "${SPECS:-}" ]; then
	logf "\n%binfo:%b No specialisations provided. Boot menu will not be modified.\n" \
		"${C_INFO}" "${C_RST}"
	exit 0
fi

first_spec="$(printf '%s\n' "${SPECS}" | cut -d',' -f1 | xargs)"
if [ -z "${first_spec}" ]; then
	logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "${C_INFO}" "${C_RST}"
	exit 0
fi

logf "\n%b>>> Attempting to set default boot option for specialisation:%b %b%s%b\n" \
	"${C_INFO}" "${C_RST}" "${C_INFO}" "${first_spec}" "${C_RST}"

default_conf="$(
	as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
		head -n1 |
		cut -d' ' -f2- ||
		true
)"

if [ -z "${default_conf}" ]; then
	err 1 "No default boot entry found in ${C_PATH}/boot/loader/loader.conf${C_RST}"
fi

if printf '%s\n' "${default_conf}" | grep -q -- "-specialisation-${first_spec}\.conf$"; then
	logf "%binfo:%b Default boot entry %balready set%b to desired %bspecialisation:%b %s\n" \
		"${C_INFO}" "${C_RST}" "${C_OK}" "${C_RST}" "${C_INFO}" "${C_RST}" "${default_conf}"
	exit 0
fi

default_base=${default_conf%.conf}
special_conf="${default_base}-specialisation-${first_spec}.conf"

if as_root test -f "/boot/loader/entries/${special_conf}"; then
	logf "Found /boot/loader/entries/%s\n" "${special_conf}"
	logf "Backing up /boot/loader/loader.conf ...\n"
	as_root cp /boot/loader/loader.conf /boot/loader/loader.backup
	logf "Setting default boot to %s\n" "${special_conf}"
	as_root sed -i "s|^default .*|default ${special_conf}|" /boot/loader/loader.conf

	new_default="$(
		as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
			head -n1 |
			cut -d' ' -f2- ||
			true
	)"

	if [ "${new_default}" = "${special_conf}" ]; then
		logf "%b✔ success:%b default boot set to: %b%s%b\n" "${C_OK}" "${C_RST}" \
			"${C_PATH}" "${special_conf}" "${C_RST}"
		exit 0
	else
		logf "%b✖ error:%b failed to update default boot entry. Current setting: %s\n" \
			"${C_ERR}" "${C_RST}" "$new_default"
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
		"${C_WARN}" "${C_RST}" "$special_conf"
	exit 0
fi
