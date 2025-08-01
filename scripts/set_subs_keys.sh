#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

check_for_nix exit

logf "\n%b>>> Cache configuration started...%b\n" "$BLUE" "$RESET"

# Sanity check
if [ -z "${NIX_CACHE_URLS:-}" ]; then
	logf "\n%b⚠️warning:%b %bUSE_CACHE%b was enabled but no NIX_CACHE_URLS were set.\nCheck your make.env file.\n" "$YELLOW" "$RESET" "$BLUE" "$RESET"
	exit 1
fi

csv_to_space() {
	printf "%s" "$1" | tr ',' ' '
}

# Paths
user_nix_conf="$HOME/.config/nix/nix.conf"
nix_conf="/etc/nix/nix.conf"

# Ensure files exist
mkdir -p "$(dirname "$user_nix_conf")"
[ -f "$user_nix_conf" ] || touch "$user_nix_conf"

sudo mkdir -p "$(dirname "$nix_conf")"
[ -f "$nix_conf" ] || sudo touch "$nix_conf"

# Replace or add a key/value in a config file
set_conf_value() {
	file="$1"
	key="$2"
	value="$3"
	if grep -q "^${key}[[:space:]]*=" "$file"; then
		if sed --version >/dev/null 2>&1; then
			# GNU sed
			sudo sed -i "s|^${key}[[:space:]]*=.*|$key = $value|" "$file"
		else
			# BSD sed (macOS)
			sudo sed -i "" "s|^${key}[[:space:]]*=.*|$key = $value|" "$file"
		fi
	else
		printf "%s = %s\n" "${key}" "$value" >> "$file"
	fi
}

# trusted-public-keys in /etc/nix/nix.conf
if [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
	trusted_keys=$(csv_to_space "$TRUSTED_PUBLIC_KEYS")
	logf "\n%binfo:%b setting %btrusted-public-keys%b = %s \nin %b%s%b\n" \
		"$BLUE" "$RESET" "$CYAN" "$RESET" "$trusted_keys" "$MAGENTA" "$nix_conf" "$RESET"
	set_conf_value "$nix_conf" "trusted-public-keys" "$trusted_keys"
fi

# trusted-substituters in /etc/nix/nix.conf
cache_urls=$(csv_to_space "$NIX_CACHE_URLS")
logf "\n%binfo:%b setting %btrusted-substituters%b = %s \nin %b%s%b\n" \
	"$BLUE" "$RESET" "$CYAN" "$RESET" "$cache_urls" "$MAGENTA" "$nix_conf" "$RESET"
set_conf_value "$nix_conf" "trusted-substituters" "$cache_urls"

# Set download-buffer-size if not already set
if ! grep -q '^download-buffer-size[[:space:]]*=' "$nix_conf"; then
	printf "download-buffer-size = 1G\n" | sudo tee -a "$nix_conf" >/dev/null
	logf "\n%binfo:%b setting %bdownload-buffer-size%b = 1G \nin %b%s%b\n" \
		"$BLUE" "$RESET" "$CYAN" "$RESET" "$MAGENTA" "$nix_conf" "$RESET"
else
	logf "\n%binfo:%b download-buffer-size already set in %s, not modifying.\n" "$BLUE" "$RESET" "$nix_conf"
fi

# substituters in user config
logf "\n%binfo:%b setting %bsubstituters%b = %s \nin %b%s%b\n" \
	"$BLUE" "$RESET" "$CYAN" "$RESET" "$cache_urls" "$MAGENTA" "$user_nix_conf" "$RESET"
set_conf_value "$user_nix_conf" "substituters" "$cache_urls"

# Restart daemon
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
