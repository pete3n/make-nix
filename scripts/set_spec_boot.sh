#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

if is_truthy "${DRY_RUN:-}" || ! is_truthy "${BOOT_SPEC:-}"; then
	exit 0
fi

if [ -z "${SPECS:-}" ]; then
	logf "\n%binfo:%b No specialisations specified. Skipping setting default boot...\n" "$BLUE" "$RESET"
	exit 0
fi

first_spec=$(printf '%s\n' "$SPECS" | cut -d',' -f1 | xargs)

if [ -z "$first_spec" ]; then
	logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "$BLUE" "$RESET"
	exit 0
fi

logf "\n%b>>> Attempting to set default boot option for specialisation:%b %b%s%b\n" \
	"$BLUE" "$RESET" "$CYAN" "$first_spec" "$RESET"

default_conf=$(
	as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
		head -n1 |
		cut -d' ' -f2- ||
		true
)

if [ -z "$default_conf" ]; then
	logf "%berror:%b No default boot entry found in /boot/loader/loader.conf\n" "$RED" "$RESET"
	exit 1
fi

if printf '%s\n' "$default_conf" | grep -q -- "-specialisation-${first_spec}\.conf$"; then
	logf "%binfo:%b Default boot entry %balready set%b to desired %bspecialisation:%b %s\n" \
		"$BLUE" "$RESET" "$GREEN" "$RESET" "$CYAN" "$RESET" "$default_conf"
	exit 0
fi

default_base=${default_conf%.conf}
special_conf="${default_base}-specialisation-${first_spec}.conf"

if as_root test -f "/boot/loader/entries/$special_conf"; then
	logf "Found /boot/loader/entries/%s\n" "$special_conf"
	logf "Backing up /boot/loader/loader.conf ...\n"
	as_root cp /boot/loader/loader.conf /boot/loader/loader.backup
	logf "Setting default boot to %s\n" "$special_conf"
	as_root sed -i "s|^default .*|default $special_conf|" /boot/loader/loader.conf

	new_default=$(
		as_root grep '^default[[:space:]]' /boot/loader/loader.conf |
			head -n1 |
			cut -d' ' -f2- ||
			true
	)

	if [ "$new_default" = "$special_conf" ]; then
		logf "%b✔ success:%b default boot set to: %b%s%b\n" "$GREEN" "$RESET" \
			"$MAGENTA" "$special_conf" "$RESET"
		exit 0
	else
		logf "%b✖ error:%b failed to update default boot entry. Current setting: %s\n" "$RED" "$RESET" "$new_default"
		logf "Reverting changes to backup...\n"
		if as_root cp /boot/loader/loader.backup /boot/loader/loader.conf; then
			logf "%b✔ success:%b backup restored.\n" "$GREEN" "$RESET"
		else
			logf "%b✖ error:%b failed to restore backup. Please perform manual restore of /boot/loader/loader.conf\n" "$RED" "$RESET"
		fi
		exit 1
	fi
else
	logf "%b⚠️warning:%b specialisation config not found: /boot/loader/entries/%s\n" "$YELLOW" "$RESET" "$special_conf"
	exit 1
fi
