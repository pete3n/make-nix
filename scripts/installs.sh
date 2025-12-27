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

	curl -fLs "${_url}" > "${MAKE_NIX_INSTALLER}" || err 1 "Download failed: ${_url}"
	# shellcheck disable=SC2046
	set -- $(shasum "${MAKE_NIX_INSTALLER}")
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

_launch_homebrew_install() {
	if [ "${UNAME_S:-}" != "Darwin" ]; then
		err 1 "Homebrew can only be installed on MacOS.\n"
	fi

	if [ -x "/usr/local/bin/brew" ] || has_cmd "brew"; then
		logf "Homebrew already installed. Skipping install.\n"
		return 0
	fi

	if ! has_cmd "bash"; then
		err 1 "bash was not found. This is required for Homebrew installation.\n"
	fi

	logf "\n%b>>> Installing Homebrew...%b\n" "${C_INFO}" "${C_RST}"
	logf "\n%binfo:%bVerifying Homebrew installer integrity...\n" "${C_INFO}" "${C_RST}"
	# Overwrites previous mktmp installer
	_check_integrity "${HOMEBREW_INSTALL_URL}" "${HOMEBREW_INSTALL_HASH}"
	bash -c "${MAKE_NIX_INSTALLER}"
}

_launch_darwin_install() {
	if [ "${UNAME_S:-}" != "Darwin" ]; then
		err 1 "Darwin can only be installed on MacOS.\n"
	fi
		logf "\n%b>>> Installing nix-darwin...%b\n" "${C_INFO}" "${C_RST}"
		
		if ! has_cmd "nix"; then
			source_nix
			if ! has_cmd "nix"; then
				err 1 "nix not found. Run ${C_CMD}make install${C_RST} to install it."
			fi
		fi
		sh "${_script_dir}/install_nix_darwin.sh"
}

# Exit early if Nix is installed and we are not installing Darwin
if has_cmd "nix" && ! is_truthy "${INSTALL_DARWIN:-}"; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "${C_INFO}" "${C_RST}"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
	exit 0
fi

# Only the determinate installer works with SELinux
if [ -z "${USE_DETERMINATE:-}" ]; then
	if has_cmd "getenforce"; then
		case "$(getenforce 2>/dev/null)" in
		"Enforcing"|"Permissive")
			logf "\n%binfo:%b SELinux detected (%s). Using Determinate Systems installer.\n" \
				"${C_INFO:-}" "${C_RST:-}" "$(getenforce)"
			USE_DETERMINATE="true"
			;;
		esac
	elif [ -f /sys/fs/selinux/enforce ] && [ "$(cat /sys/fs/selinux/enforce 2>/dev/null)" = "1" ]; then
		logf "\n%binfo:%b SELinux detected (sysfs).  Using Determinate Systems installer.\n" \
			"${C_INFO:-}" "${C_RST:-}"
		USE_DETERMINATE="true"
	fi
fi

# Integrity checks
if is_truthy "${USE_DETERMINATE:-}"; then
	logf "\n%b>>> Verifying Determinate Systems installer integrity...%b\n" "${C_INFO}" "${C_RST}"
	_check_integrity "${DETERMINATE_INSTALL_URL}" "${DETERMINATE_INSTALL_HASH}"
else
	logf "\n%b>>> Verifying Nix installer integrity...%b\n" "${C_INFO}" "${C_RST}"
	_check_integrity "${NIX_INSTALL_URL}" "${NIX_INSTALL_HASH}"
fi

# Launch installers
logf "\n%b>>> Launching installer...%b\n" "${C_INFO}" "${C_RST}"

if is_truthy "${USE_DETERMINATE:-}"; then
	set -- "${DETERMINATE_INSTALL_MODE}"
else
	if is_truthy "${SINGLE_USER:-}"; then
		set -- "--no-daemon"
	else
		set -- "${NIX_INSTALL_MODE}"
	fi
fi

if [ -f "${MAKE_NIX_INSTALLER}" ]; then
	sh "${MAKE_NIX_INSTALLER}" "$@"

	# Make nix available in the current shell after install for follow-on targets
	source_nix

else
	err 1 "Could not execute ${C_PATH}${MAKE_NIX_INSTALLER}${C_RST}"
fi

# Set user-defined binary cache URLs and Nix trusted public keys from make.env.
# This is set before Nix-Darwin install so it can take advantage of caching.
if is_truthy "${USE_KEYS:-}" || is_truthy "${USE_CACHE:-}"; then
	sh "${_script_dir}/set_subs_keys.sh"
fi

if is_truthy "${USE_HOMEBREW:-}"; then
	_launch_homebrew_install
fi

if is_truthy "${INSTALL_DARWIN:-}"; then
	_launch_darwin_install 
fi

if has_tag hyprland && is_truthy "${HOME_ALONE:-}" && is_truthy "${IS_LINUX}"; then
	printf "HYPRLAND_SETUP=true\n" >> "${MAKE_NIX_ENV}"
fi
