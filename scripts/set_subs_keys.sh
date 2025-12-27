#!/bin/sh

# Configure substituters and trusted keys for Nix

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

nix_conf="/etc/nix/nix.conf"
conf_d="/etc/nix/nix.conf.d"
dropin_conf="${conf_d}/50-make-nix.conf"
include_line="include ${dropin_conf}"

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found. Run ${C_CMD}make install${C_RST} to install it."
	fi
fi

_csv_to_space() {
  printf "%s" "$1" | tr ',' ' ' | tr -s ' '
}

logf "\n%b>>> Cache configuration started...%b\n" "${C_INFO}" "${C_RST}"

# Warn if cache env URLs are missing
if is_truthy "${USE_CACHE:-}" && [ -z "${NIX_CACHE_URLS:-}" ]; then
	logf "\n%b⚠️ warning:%b %bUSE_CACHE%b was enabled but no NIX_CACHE_URLS were set.\nCheck your make.env file.\n" \
		"${C_WARN}" "${C_RST}" "${C_INFO}" "${C_RST}"
	exit 0 # Don't halt the installation
fi

if is_truthy "${USE_KEYS:-}" && [ -z "${TRUSTED_PUBLIC_KEYS:-}" ]; then
	_msg="\n${C_WARN}⚠️ warning:${C_RST} ${C_INFO}USE_KEYS${C_RST} was enabled " 
	_msg="${_msg}but no TRUSTED_PUBLIC_KEYS were set.\nCheck your make.env file.\n"
	logf "%b" "${_msg}"
	exit 0 # Don't halt the installation
fi

as_root mkdir -p "${conf_d}"

_tmpdir="${MAKE_NIX_TMPDIR:-/tmp}"
[ -d "$_tmpdir" ] || _tmpdir="/tmp"
_tmp=$(mktemp "$_tmpdir/nixconf.XXXXXX") || return 1

{
  printf "%s\n\n" "# Managed by make-nix (do not edit by hand)"

  if is_truthy "${USE_CACHE:-}" && [ -n "${NIX_CACHE_URLS:-}" ]; then
    _cache_urls=$(_csv_to_space "${NIX_CACHE_URLS}")
    printf "trusted-substituters = %s\n" "${_cache_urls}"
  fi

  if is_truthy "${USE_KEYS:-}" && [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
    _keys=$(_csv_to_space "${TRUSTED_PUBLIC_KEYS}")
    printf "trusted-public-keys = %s\n" "${_keys}"
  fi

  printf "\ndownload-buffer-size = 1G\n"
} > "${_tmp}"

as_root cp "${_tmp}" "${dropin_conf}"
rm -f "${_tmp}"

# Ensure nix.conf exists
if [ ! -e "${nix_conf}" ]; then
  as_root sh -c "printf '%s\n' '# Managed by make-nix (do not edit by hand)' '${include_line}' > '${nix_conf}'"
else
  if [ -L "${nix_conf}" ]; then
    logf "%b⚠️ warning:%b %b%s%b is a symlink; cannot safely add include. Drop-in was written to %b%s%b but may not be read.\n" \
      "${C_WARN}" "${C_RST}" "${C_PATH}" "${nix_conf}" "${C_RST}" "${C_PATH}" "${dropin_conf}" "${C_RST}"
    exit 0
  fi

  if ! as_root sh -c "grep -qF '${include_line}' '${nix_conf}'"; then
    as_root sh -c "printf '\n%s\n' '${include_line}' >> '${nix_conf}'"
  fi
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
