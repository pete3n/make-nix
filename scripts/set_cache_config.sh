#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT
trap '[ -n "${tmp:-}" ] && rm -f "$tmp"' EXIT INT TERM QUIT

check_for_nix exit
logf "\n%b>>> Cache configuration started...%b\n" "$BLUE" "$RESET"

if [ -z "${NIX_CACHE_URLS:-}" ]; then
	logf "\n%b⚠️warning:%b %bUSE_CACHE%b was enabled but no CACHE_URLS were set.\n 
	Check your make.env file.\n" "$YELLOW" "$RESET" "$BLUE" "$RESET"
	exit 1
fi

quote_csv_list() {
	list_csv="$1"
	result=""
	IFS=','
	for val in $list_csv; do
		result="$result \"$val\""
	done
	printf "%s\n" "$result"
}

if check_for_nixos no-exit; then
	logf "\n%bbinfo:%b NixOS was detected. Cache settings must be defined in your system's configuration.nix:\n" "$BLUE" "$RESET"
	logf "\n  Example:\n"
	logf "    %bnix.settings.trusted-substituters = [ %s ];\n" "$(quote_csv_list "$NIX_CACHE_URLS")" "$GREEN" "$RESET"
	if [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
		logf "    nix.settings.trusted-public-keys = [ %s ];\n" "$(quote_csv_list "$TRUSTED_PUBLIC_KEYS")" "$GREEN" "$RESET"
	fi
	printf "\nContinue without configuring caching in this script? [y/N]: "
	read -r ack
	case "$ack" in
	[Yy]*) exit 0 ;;
	*)
		logf "\n%binfo:%b Exiting without changes...\n" "$BLUE" "$RESET"
		exit 1
		;;
	esac
fi

nix_conf="/etc/nix/nix.conf"
sudo mkdir -p "$(dirname "$nix_conf")"
[ -f "$nix_conf" ] || sudo touch "$nix_conf"

# Deduplicates and prepends new values
merge_values() {
	key="$1"
	new_csv="$2"

	# Parse existing space-separated values
	existing_line=$(grep "^$key =" "$nix_conf" 2>/dev/null || true)
	if [ -n "$existing_line" ]; then
		existing_values=$(printf "%s\n" "$existing_line" | cut -d'=' -f2- | sed 's/^ *//')
	else
		existing_values=""
	fi

	# Parse new comma-separated values
	new_values=$(printf "%s" "$new_csv" | tr ',' ' ')

	# Prepend new values, preserve order, deduplicate
	combined=""
	for val in $new_values $existing_values; do
		case " $combined " in
		*" $val "*) : ;; # skip duplicate
		*) combined="$combined $val" ;;
		esac
	done

	printf "%s\n" "$combined" | sed 's/^ *//'
}

set_key_value() {
	key="$1"
	value="$2"
	if grep -q "^$key =" "$nix_conf"; then
		tmp="$(mktemp)"
		sed "s|^$key =.*|$key = $value|" "$nix_conf" >"$tmp"
		sudo mv "$tmp" "$nix_conf"
	else
		printf "%s = %s\n" "$key" "$value" | sudo tee -a "$nix_conf" >/dev/null
	fi
}

# Handle trusted-substituters (prepend new)
if [ -n "${NIX_CACHE_URLS:-}" ]; then
	merged_subs=$(merge_values "trusted-substituters" "$NIX_CACHE_URLS")
	logf "\n%binfo:%b setting %btrusted-substituters%b = %s \nin %b%s%b\n" \
		"$BLUE" "$RESET" "$CYAN" "$RESET" "$merged_subs" "$MAGENTA" "$nix_conf" "$RESET"

	set_key_value "trusted-substituters" "$merged_subs"

	# Set download-buffer-size = 1G if not already set
	# https://github.com/NixOS/nix/issues/11728
	if ! grep -q '^download-buffer-size[[:space:]]*=' "$nix_conf"; then
		echo "download-buffer-size = 1G" >>"$nix_conf"
		logf "\n%binfo:%b setting %bdownload-buffer-size%b = 1G \nin %b%s%b\n" \
			"$BLUE" "$RESET" "$CYAN" "$RESET" "$MAGENTA" "$nix_conf" "$RESET"
	else
		logf "\n%bbinfo:%b download-buffer-size already set in %s, not modifying.\n" "$BLUE" "$RESET" "$user_nix_conf"
	fi

	# Ensure user's nix.conf exists
	user_nix_conf="$HOME/.config/nix/nix.conf"
	mkdir -p "$(dirname "$user_nix_conf")"
	[ -f "$user_nix_conf" ] || touch "$user_nix_conf"

	# Sync substituters = to user's config
	user_sub_line=$(grep '^substituters =' "$user_nix_conf" 2>/dev/null || true)
	user_subs=$(printf "%s\n" "$user_sub_line" | cut -d'=' -f2- | sed 's/^ *//')
	merged_user_subs=""
	for val in $(printf "%s" "$NIX_CACHE_URLS" | tr ',' ' ') $user_subs; do
		case " $merged_user_subs " in
		*" $val "*) : ;; # skip duplicate
		*) merged_user_subs="$merged_user_subs $val" ;;
		esac
	done
	merged_user_subs="$(echo "$merged_user_subs" | sed 's/^ *//')"

	if [ -n "$merged_user_subs" ]; then
		if grep -q '^substituters =' "$user_nix_conf"; then
			sed -i "s|^substituters =.*|substituters = $merged_user_subs|" "$user_nix_conf"
		else
			printf "substituters = %s\n" "$merged_user_subs" >>"$user_nix_conf"
		fi
		logf "\n%binfo:%b setting %bsubstituters%b = %s \nin %b%s%b\n" \
			"$BLUE" "$RESET" "$CYAN" "$RESET" "$merged_user_subs" "$MAGENTA" "$user_nix_conf" "$RESET"
	fi

fi

# TODO: Implement with trusted-user configuration for binary cache and builders
# Handle trusted-public-keys (merge, keep original order)
#if [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
#	merged_keys=$(merge_values "trusted-public-keys" "$TRUSTED_PUBLIC_KEYS")
#	logf "\n%binfo:%b setting %btrusted-public-keys%b = %s \nin %b%s%b\n" \
#		"$BLUE" "$RESET" "$CYAN" "$RESET" "$merged_keys" "$MAGENTA" "$nix_conf" "$RESET"
#	set_key_value "trusted-public-keys" "$merged_keys"
#fi

logf "%b>>> Restarting Nix daemon to apply changes...%b\n" "$BLUE" "$RESET"
case "$(uname)" in
Darwin)
	if sudo launchctl kickstart -k system/org.nixos.nix-daemon; then
		logf "%b✓ nix-daemon restarted successfully on macOS.%b\n" "$GREEN" "$RESET"
	else
		logf "%b⚠️warning:%b Failed to restart nix-daemon on macOS.\n" "$YELLOW" "$RESET"
	fi
	;;
Linux)
	if command -v systemctl >/dev/null 2>&1 && systemctl list-units | grep -q nix-daemon; then
		if sudo systemctl restart nix-daemon; then
			logf "%b✓ nix-daemon restarted successfully on Linux.%b\n" "$GREEN" "$RESET"
		else
			logf "%b⚠️warning:%b Failed to restart nix-daemon on Linux.\n" "$YELLOW" "$RESET"
		fi
	fi
	;;
esac
