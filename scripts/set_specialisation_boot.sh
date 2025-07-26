#!/usr/bin/env sh
set -eu

# Exit if DRY_RUN is defined OR BOOT_SPEC is undefined
if [ -n "${DRY_RUN+x}" ] || [ -z "${BOOT_SPEC+x}" ]; then
	exit 0
fi

env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -z "${TGT_SPEC:-}" ]; then
	printf "%binfo:%b No specialisations specified.\nSkipping setting boot specialisation...\n" "$BLUE" "$RESET"
	exit 0
fi

first_spec=$(printf '%s\n' "$TGT_SPEC" | cut -d',' -f1 | xargs)

if [ -z "$first_spec" ]; then
	printf "%binfo:%b No valid specialisation found. Skipping...\n" "$BLUE" "$RESET"
	exit 0
fi

printf "\nAttempting to set default boot option for specialisation: %s\n" "$first_spec"

default_conf=$(grep '^default ' /boot/loader/loader.conf | cut -d' ' -f2 || true)
if [ -z "$default_conf" ]; then
	printf "%berror:%b No default boot entry found in /boot/loader/loader.conf\n" "$RED" "$RESET"
	exit 1
fi

if printf '%s\n' "$default_conf" | grep -q -- "-specialisation-${first_spec}\.conf$"; then
  printf "%binfo:%b Default boot entry %balready set%b to desired %bspecialisation:%b %s\n" \
		"$BLUE" "$RESET" "$GREEN" "$RESET" "$CYAN" "$RESET" "$default_conf"
  exit 0
fi

default_base=${default_conf%.conf}
special_conf="${default_base}-specialisation-${first_spec}.conf"

if [ -f "/boot/loader/entries/$special_conf" ]; then
	printf "Found /boot/loader/entries/%s\n" "$special_conf"
	printf "Backing up /boot/loader/loader.conf ...\n"
	sudo cp /boot/loader/loader.conf /boot/loader/loader.backup
	printf "Setting default boot to %s\n" "$special_conf"
	sudo sed -i "s|^default .*|default $special_conf|" /boot/loader/loader.conf
	
	new_default=$(grep '^default ' /boot/loader/loader.conf | cut -d' ' -f2 || true)

	if [ "$new_default" = "$special_conf" ]; then
		printf "%b✔%b Successfully set default boot to: %s\n" "$GREEN" "$RESET" "$special_conf"
		exit 0
	else
		printf "%b✖%b Failed to update default boot entry. Current setting: %s\n" "$RED" "$RESET" "$new_default"
		printf "Reverting changes to backup...\n" 
		if sudo cp /boot/loader/loader.backup /boot/loader/loader.conf; then
			printf "%b✔%b Backup restored.\n" "$GREEN" "$RESET"
		else
			printf "%b✖%b Failed to restore backup. Please perform manual restore of /boot/loader/loader.conf\n" "$RED" "$RESET"
		fi
		exit 1
	fi
else
	printf "%b⚠️%b Specialisation config not found: /boot/loader/entries/%s\n" "$YELLOW" "$RESET" "$special_conf"
	exit 1
fi
