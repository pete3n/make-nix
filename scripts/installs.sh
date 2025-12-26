#!/usr/bin/env sh
set -eu

is_final_goal=0

while getopts ':F:' opt; do
  case "$opt" in
    F)
      case "$OPTARG" in
        0|1) is_final_goal=$OPTARG ;;
        *) printf '%s: invalid -F value: %s (expected 0 or 1)\n' "${0##*/}" "$OPTARG" >&2; exit 2 ;;
      esac
      ;;
    :)
      printf '%s: option -%s requires an argument\n' "${0##*/}" "$OPTARG" >&2
      exit 2
      ;;
    \?)
      printf '%s: invalid option -- %s\n' "${0##*/}" "$OPTARG" >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))

_script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$_script_dir/common.sh"

_cleanup_on_exit() {
  status=$?
  if [ "$status" -ne 0 ] && [ "${is_final_goal:-0}" -eq 1 ]; then
    cleanup "$status" "ERROR"
  fi
  exit "$status"
}

trap '_cleanup_on_exit' 0

trap '
  [ "${is_final_goal:-0}" -eq 1 ] && cleanup 130 SIGNAL
  exit 130
' INT TERM QUIT

_check_integrity() {
	_url="${1}"
	_expected_hash="${2}"

	curl -fLs "${_url}" > "$MAKE_NIX_INSTALLER" || err 1 "Download failed: ${_url}"
	# shellcheck disable=SC2046
	set -- $(shasum "$MAKE_NIX_INSTALLER")
	_actual_hash="${1}"

	if [ "${_actual_hash}" != "${_expected_hash}" ]; then
		rm "${MAKE_NIX_INSTALLER}"
		_msg="Expected:	${C_CFG}${_expected_hash}${C_RST}\n"
		_msg="${_msg}Actual: ${C_ERR}${_actual_hash}${C_RST}\n"
		_msg="${_msg}Check the URL and hash values in your make.env file."
		err 1 "${C_WARN}Integrity check failed!${C_RST}\n${_msg}"
	else
		logf "\n%b✅ Integrity check passed.%b\n" "${C_OK}" "${C_RST}"
		chmod +x "${MAKE_NIX_INSTALLER}"
	fi
}

# Only the determinate installer works with SELinux
if [ -z "${DETERMINATE:-}" ]; then
	if has_cmd "getenforce"; then
		case "$(getenforce 2>/dev/null)" in
		"Enforcing"|"Permissive")
			logf "\n%binfo:%b SELinux detected (%s). Using Determinate Systems installer.\n" \
				"${C_INFO:-}" "${C_RST:-}" "$(getenforce)"
			DETERMINATE=true
			;;
		esac
	elif [ -f /sys/fs/selinux/enforce ] && [ "$(cat /sys/fs/selinux/enforce 2>/dev/null)" = "1" ]; then
		logf "\n%binfo:%b SELinux detected (sysfs).  Using Determinate Systems installer.\n" \
			"${C_INFO:-}" "${C_RST:-}"
		DETERMINATE=true
	fi
fi

# Integrity checks
if is_truthy "${DETERMINATE:-}"; then
	logf "\n%b>>> Verifying Determinate Systems installer integrity...%b\n" "$C_INFO" "$C_RST"
	_check_integrity "$DETERMINATE_INSTALL_URL" "$DETERMINATE_INSTALL_HASH"
else
	logf "\n%b>>> Verifying Nix installer integrity...%b\n" "$C_INFO" "$C_RST"
	_check_integrity "$NIX_INSTALL_URL" "$NIX_INSTALL_HASH"
fi

# Launch installers
logf "\n%b>>> Launching installer...%b\n" "$C_INFO" "$C_RST"

if is_truthy "${DETERMINATE:-}"; then
	set -- "$DETERMINATE_INSTALL_MODE"
else
	if is_truthy "${SINGLE_USER:-}"; then
		set -- "--no-daemon"
	else
		set -- "$NIX_INSTALL_MODE"
	fi
fi

if has_cmd "nix"; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$C_INFO" "$C_RST"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$@"

		# Make nix available immediately in the current shell
		source_nix

	else
		err 1 "Could not execute ${C_PATH}${MAKE_NIX_INSTALLER}${C_RST}"
	fi
fi

# Enabled flakes (Required before Nix-Darwin install)
nix_conf="$HOME/.config/nix/nix.conf"
features="experimental-features = nix-command flakes"

if [ -f "$nix_conf" ]; then
	if ! grep -qF "nix-command flakes" "$nix_conf"; then
		logf "\n%b>>> Enabling flakes...%b\n" "$C_INFO" "$C_RST"
		logf "\n%binfo:%b appending %s to %b%s%b\n" "$C_INFO" "$C_RST" "$features" \
			"$C_PATH" "$nix_conf" "$C_RST"
		printf "%s\n" "$features" >>"$nix_conf"
	fi
else
	logf "\n%b>>> Creating nix.conf with experimental features enabled...%b\n" "$C_INFO" "$C_RST"
	mkdir -p "$(dirname "$nix_conf")"
	printf "%s\n" "$features" >"$nix_conf"
fi

# Set user-defined binary cache URLs and Nix trusted public keys from make.env.
# This is set before Nix-Darwin install so it can take advantage of cacheing.
if is_truthy "${USE_KEYS:-}" || is_truthy "${USE_CACHE:-}"; then
	sh "$_script_dir/set_subs_keys.sh"
fi

# Optional Homebrew install
if is_truthy "${USE_HOMEBREW:-}" && [ "${UNAME_S}" = "Darwin" ]; then
	logf "\n%b>>> Installing Homebrew...%b\n" "$C_INFO" "$C_RST"
	logf "\n%binfo:%bVerifying Homebrew installer integrity...\n" "$C_INFO" "$C_RST"
	# Overwrites previous mktmp installer
	_check_integrity "$HOMEBREW_INSTALL_URL" "$HOMEBREW_INSTALL_HASH"
	if has_cmd "bash"; then
		bash -c "$MAKE_NIX_INSTALLER"
	else
		logf "\n%berror:%b bash was not found. This is required for Homebrew installation.\n" "$C_ERR" "$C_RST"
		exit 1
	fi
fi

# Optional Nix-Darwin install
if is_truthy "${INSTALL_DARWIN:-}"; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		logf "\n%b>>> Installing nix-darwin...%b\n" "${C_INFO}" "${C_RST}"
		
		if ! has_cmd "nix"; then
			source_nix
			if ! has_cmd "nix"; then
				err 1 "nix not found. Run {$C_CMD}make install{$C_RST} to install it."
			fi
		fi
		sh "$_script_dir/install_nix_darwin.sh"

	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$C_INFO" "$C_RST"
		exit 0
	fi
fi

if has_tag hyprland && is_truthy "${HOME_ALONE:-}" && is_truthy "${IS_LINUX}"; then
	printf "HYPRLAND_SETUP=true\n" >> "$MAKE_NIX_ENV"
fi
