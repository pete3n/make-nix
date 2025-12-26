#!/bin/sh

# Configure substituters and trusted keys for Nix

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

nix_conf="/etc/nix/nix.conf"

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found. Run {$C_CMD}make install{$C_RST} to install it."
	fi
fi

logf "\n%b>>> Cache configuration started...%b\n" "$C_INFO" "$C_RST"

# Warn if cache env URLs are missing
if is_truthy "${USE_CACHE:-}" && [ -z "${NIX_CACHE_URLS:-}" ]; then
	logf "\n%b⚠️ warning:%b %bUSE_CACHE%b was enabled but no NIX_CACHE_URLS were set.\nCheck your make.env file.\n" \
		"${C_WARN}" "${C_RST}" "${C_INFO}" "${C_RST}"
	exit 0 # Don't halt the installation
fi

if is_truthy "${USE_KEYS:-}" && [ -z "${TRUSTED_PUBLIC_KEYS:-}" ]; then
	logf "\n%b⚠️ warning:%b %bUSE_KEYS%b was enabled but no TRUSTED_PUBLIC_KEYS were set.\nCheck your make.env file.\n" \
		"${C_WARN}" "${C_RST}" "${C_INFO}" "${C_RST}"
	exit 0 # Don't halt the installation
fi

_csv_to_space() {
  printf "%s" "$1" | tr ',' ' ' | tr -s ' '
}

# Only modify nix.conf if it is a broken symlink (safe to repair).
# A regular file or valid symlink indicates active Nix management.
if ! is_deadlink "${nix_conf}"; then
  logf "\n%b⚠️ warning:%b %b%s%b exists and is managed by Nix. Can't modify.\n" \
		"${C_WARN}" "${C_RST}" "${C_PATH}" "${nix_conf}" "${C_RST}"
	exit 0
fi

as_root mkdir -p "$(dirname "${nix_conf}")"
[ -f "${nix_conf}" ] || as_root touch "${nix_conf}"

# Replace or add a key/value in a config file
_set_conf_value() {
	_file="${1}"
	_key="${2}"
	_value="${3}"
	if as_root sh -c grep -q "^${_key}[[:space:]]*=" "${_file}"; then
		if sed --version >/dev/null 2>&1; then
			# GNU sed
			as_root sed -i "s|^${_key}[[:space:]]*=.*|${_key} = ${_value}|" "${_file}"
		else
			# BSD sed (macOS)
			as_root sed -i "" "s|^${_key}[[:space:]]*=.*|${_key} = ${_value}|" "${_file}"
		fi
	else
		printf "%s = %s\n" "${_key}" "${_value}" | as_root tee -a "${_file}"
	fi
}

# trusted-public-keys in /etc/nix/nix.conf
if [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
	trusted_keys=$(_csv_to_space "${TRUSTED_PUBLIC_KEYS}")
	logf "\n%binfo:%b setting %btrusted-public-keys%b = %s \nin %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${trusted_keys}" "${C_PATH}" "${nix_conf}" "${C_RST}"
	_set_conf_value "${nix_conf}" "trusted-public-keys" "${trusted_keys}"
fi

# trusted-substituters in /etc/nix/nix.conf
cache_urls=$(_csv_to_space "${NIX_CACHE_URLS}")
logf "\n%binfo:%b setting %btrusted-substituters%b = %s \nin %b%s%b\n" \
	"${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${cache_urls}" "${C_PATH}" "${nix_conf}" "${C_RST}"
_set_conf_value "${nix_conf}" "trusted-substituters" "${cache_urls}"

# substituters in /etc/nix/nix.conf (default caches used)
logf "\n%binfo:%b setting %bsubstituters%b = %s \nin %b%s%b\n" \
  "${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${cache_urls}" "${C_PATH}" "${nix_conf}" "${C_RST}"
_set_conf_value "${nix_conf}" "substituters" "${cache_urls}"

# Set download-buffer-size if not already set
if ! as_root sh -c grep -q '^download-buffer-size[[:space:]]*=' "${nix_conf}"; then
	printf "download-buffer-size = 1G\n" | as_root tee -a "${nix_conf}" >/dev/null
	logf "\n%binfo:%b setting %bdownload-buffer-size%b = 1G \nin %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${C_PATH}" "${nix_conf}" "${C_RST}"
else
	logf "\n%binfo:%b download-buffer-size already set in %s, not modifying.\n" \
		"${C_INFO}" "${C_RST}" "${C_PATH}" "${nix_conf}" "${C_RST}"
fi

# Restart daemon
logf "%b>>> Restarting Nix daemon to apply changes...%b\n" "${C_INFO}" "${C_RST}"
case "${UNAME_S:-}" in
Darwin)
	if as_root launchctl kickstart -k system/org.nixos.nix-daemon; then
		logf "%b✓ nix-daemon restarted successfully on macOS.%b\n" "${C_OK}" "${C_RST}"
	else
		logf "%b⚠️warning:%b Failed to restart nix-daemon on macOS.\n" "${C_WARN}" "${C_RST}"
	fi
	;;
Linux)
	if has_cmd "systemctl" && [ -d /run/systemd/system ]; then
		if systemctl is-active --quiet nix-daemon 2>/dev/null; then
			if as_root systemctl restart nix-daemon; then
				logf "%b✓ nix-daemon restarted successfully on Linux.%b\n" "${C_OK}" "${C_RST}"
			else
				logf "%b⚠️warning:%b Failed to restart nix-daemon on Linux.\n" "${C_WARN}" "${C_RST}"
			fi
		fi
	fi
	;;
esac
