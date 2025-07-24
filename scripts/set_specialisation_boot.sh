#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

if [ -z "${spec:-}" ]; then
	printf "%binfo:%b No specialisation specified. Cannot set default boot specialisation...\n" "$BLUE" "$RESET"
	exit 0
fi

IFS=', ' read -r first_spec _ <<EOF
$spec
EOF

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

special_conf="${default_conf}%-specialisation-${first_spec}.conf"

if [ -f "/boot/loader/entries/$special_conf" ]; then
	printf "Found /boot/loader/entries/%s\n" "$special_conf"
	printf "Backing up /boot/loader/loader.conf\n"
	sudo cp /boot/loader/loader.conf /boot/loader/loader.backup
	printf "Setting default boot to %s\n" "$special_conf"
	sudo sed -i "s|^default .*|default $special_conf|" /boot/loader/loader.conf
else
	printf "%b⚠️%b Specialisation config not found: /boot/loader/entries/%s\n" "$YELLOW" "$RESET" "$special_conf"
	exit 1
fi
