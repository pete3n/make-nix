#!/bin/sh

# Configure substituters and trusted keys for Nix

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

nix_conf="/etc/nix/nix.conf"
# Prefer drop-in config when available (works with installer-managed nix.conf symlinks).
dropin_dir="/etc/nix/nix.conf.d"
dropin_file="${dropin_dir}/50-make-nix.conf"

trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found. Run {$C_CMD}make install{$C_RST} to install it."
	fi
fi

_csv_to_space() {
  printf "%s" "$1" | tr ',' ' ' | tr -s ' '
}

# Remove any existing setting lines for a key, then append "key = value".
# Preserves all other lines and comments.
_update_conf_value() {
  _file="$1"
  _key="$2"
  _value="$3"

	_tmpdir="${MAKE_NIX_TMPDIR:-/tmp}"
	[ -d "$_tmpdir" ] || _tmpdir="/tmp"
	_tmp=$(mktemp "$_tmpdir/nixconf.XXXXXX") || return 1

  # Keep everything except lines that define this key.
  # Accepts either "key=..." or "key = ..." with any spaces.
  if [ -f "$_file" ]; then
    grep -v -e "^[[:space:]]*${_key}[[:space:]]*=" "$_file" >"$_tmp" || true
  fi

  # Append the desired setting
  printf "%s = %s\n" "${_key}" "${_value}" >>"$_tmp"

  as_root mv "$_tmp" "$_file"
}

_write_dropin_file() {
  _target="$1"
  _cache_urls=""
  _trusted_keys=""

  if is_truthy "${USE_CACHE:-}" && [ -n "${NIX_CACHE_URLS:-}" ]; then
    _cache_urls=$(_csv_to_space "${NIX_CACHE_URLS}")
  fi

  if is_truthy "${USE_KEYS:-}" && [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
    _trusted_keys=$(_csv_to_space "${TRUSTED_PUBLIC_KEYS}")
  fi

  logf "\n%binfo:%b writing Nix cache/key config to %b%s%b\n" \
    "${C_INFO}" "${C_RST}" "${C_PATH}" "${_target}" "${C_RST}"

	{
		printf '%s\n' '# Managed by make-nix (do not edit)'
	} | as_root tee "${_target}" >/dev/null

  if [ -n "${_cache_urls}" ]; then
    as_root sh -c "printf '%s\n' \
      \"substituters = ${_cache_urls}\" \
      \"trusted-substituters = ${_cache_urls}\" \
      >> \"${_target}\""
  fi

  if [ -n "${_trusted_keys}" ]; then
    as_root sh -c "printf '%s\n' \
      \"trusted-public-keys = ${_trusted_keys}\" \
      >> \"${_target}\""
  fi

  as_root sh -c "printf '%s\n' 'download-buffer-size = 1G' >> \"${_target}\""
}

_overwrite_nix_conf() {
  _file="$1"

  as_root mkdir -p "$(dirname "${_file}")"
  [ -f "${_file}" ] || as_root touch "${_file}"

  if is_truthy "${USE_CACHE:-}" && [ -n "${NIX_CACHE_URLS:-}" ]; then
    _cache_urls=$(_csv_to_space "${NIX_CACHE_URLS}")
    logf "\n%binfo:%b updating %bsubstituters%b and %btrusted-substituters%b in %b%s%b\n" \
      "${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${C_CFG}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
    _update_conf_value "${_file}" "substituters" "${_cache_urls}"
    _update_conf_value "${_file}" "trusted-substituters" "${_cache_urls}"
  fi

  if is_truthy "${USE_KEYS:-}" && [ -n "${TRUSTED_PUBLIC_KEYS:-}" ]; then
    _trusted_keys=$(_csv_to_space "${TRUSTED_PUBLIC_KEYS}")
    logf "\n%binfo:%b updating %btrusted-public-keys%b in %b%s%b\n" \
      "${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
    _update_conf_value "${_file}" "trusted-public-keys" "${_trusted_keys}"
  fi

  logf "\n%binfo:%b ensuring %bdownload-buffer-size%b in %b%s%b\n" \
    "${C_INFO}" "${C_RST}" "${C_CFG}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
  _update_conf_value "${_file}" "download-buffer-size" "1G"
}

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

# Use drop-in dir if possible
_use_dropin="false"
if [ -d "${dropin_dir}" ] || as_root mkdir -p "${dropin_dir}" 2>/dev/null; then
  _use_dropin="true"
fi

if [ "${_use_dropin}" = "true" ]; then
  _write_dropin_file "${dropin_file}"
else
  # Fall back to nix.conf but don't edit Nix symlinks
  if [ -L "${nix_conf}" ] && [ -e "${nix_conf}" ]; then
    logf "\n%b⚠️ warning:%b %b%s%b is a managed symlink and no %b%s%b exists. Skipping cache/key config.\n" \
      "${C_WARN}" "${C_RST}" "${C_PATH}" "${nix_conf}" "${C_RST}" "${C_PATH}" "${dropin_dir}" "${C_RST}"
    exit 0
	else
		_overwrite_nix_conf "${nix_conf}"
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
