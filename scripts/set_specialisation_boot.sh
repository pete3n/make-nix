#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

# Exit if DRY_RUN is defined OR BOOT_SPEC is undefined
if [ -n "${DRY_RUN+x}" ] || [ -z "${BOOT_SPEC+x}" ]; then
	exit 0
fi

if [ -z "${TGT_SPEC:-}" ]; then
	logf "\n%binfo:%b No specialisations specified. Skipping setting default boot...\n" "$BLUE" "$RESET"
	exit 0
fi

first_spec=$(printf '%s\n' "$TGT_SPEC" | cut -d',' -f1 | xargs)

if [ -z "$first_spec" ]; then
	logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "$BLUE" "$RESET"
	exit 0
fi

logf "\n%b>>> Attempting to set default boot option for specialisation:%b %b%s%b\n" \
	"$BLUE" "$RESET" "$CYAN" "$first_spec" "$RESET"

default_conf=$(grep '^default ' /boot/loader/loader.conf | cut -d' ' -f2 || true)
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

if [ -f "/boot/loader/entries/$special_conf" ]; then
	logf "Found /boot/loader/entries/%s\n" "$special_conf"
	logf "Backing up /boot/loader/loader.conf ...\n"
	sudo cp /boot/loader/loader.conf /boot/loader/loader.backup
	logf "Setting default boot to %s\n" "$special_conf"
	sudo sed -i "s|^default .*|default $special_conf|" /boot/loader/loader.conf
	
	new_default=$(grep '^default ' /boot/loader/loader.conf | cut -d' ' -f2 || true)

	if [ "$new_default" = "$special_conf" ]; then
		logf "%b✔%b Successfully set default boot to: %s\n" "$GREEN" "$RESET" "$special_conf"
		exit 0
	else
		logf "%b✖%b Failed to update default boot entry. Current setting: %s\n" "$RED" "$RESET" "$new_default"
		logf "Reverting changes to backup...\n" 
		if sudo cp /boot/loader/loader.backup /boot/loader/loader.conf; then
			logf "%b✔%b Backup restored.\n" "$GREEN" "$RESET"
		else
			logf "%b✖%b Failed to restore backup. Please perform manual restore of /boot/loader/loader.conf\n" "$RED" "$RESET"
		fi
		exit 1
	fi
else
	logf "%b⚠️%b Specialisation config not found: /boot/loader/entries/%s\n" "$YELLOW" "$RESET" "$special_conf"
	exit 1
fi
