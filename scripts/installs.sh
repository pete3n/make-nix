#!/usr/bin/env sh

# Install launcher for Nix, Nix-Darwin, Homebrew, and Nixgl

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: attrs.sh failed to source common.sh from %s\n" \
	"${script_dir}/installs.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

flake_root="$(cd "${script_dir}/.." && pwd)"
host=""
user=""

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

_launch_nixgl_install() {
	_nixgl_repo="github:guibou/nixGL"
	if ! has_cmd "nix"; then
		source_nix
		if ! has_cmd "nix"; then
			err 1 "nix not found. Run ${C_CMD}make install${C_RST} to install it."
		fi
	fi

	logf "\n%b>>> Installing nixGl...%b\n" "${C_INFO}" "${C_RST}"
	set -- nix profile install --impure ${_nixgl_repo}

	print_cmd -- NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ NixGL install complete.%b\n" "${C_OK}" "${C_RST}"
		return 0
	else
		err 1 "NixGL install failed."
	fi
}

_launch_homebrew_install() {
	if [ "${UNAME_S:-}" != "Darwin" ]; then
		logf "\n%binfo:%b Homebrew can only be installed on MacOS. Skipping install...\n" \
			"${C_INFO}" "${C_RST}"
		return 0
	fi

	if [ -x "/usr/local/bin/brew" ] || has_cmd "brew"; then
		logf "Homebrew already installed. Skipping install...\n"
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
		sh "${script_dir}/install_nix_darwin.sh"

		# Make darwin-rebuild available immediately
		source_darwin
}

_launch_nix_install() {
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
}

if ! has_cmd "nix"; then
	source_nix
	if has_cmd "nix"; then
		logf "\n%binfo:%b Nix already installed. Skipping install...\n" "${C_INFO}" "${C_RST}"
		logf "If you want to re-install, please run 'make uninstall' first.\n"
	else
		_launch_nix_install 
	fi
fi

# Either use a hostname provided from commandline args or default to current hostname
if [ -z "${TGT_HOST:-}" ]; then
	host="$(uname -n)"
	if [ -z "${host}" ]; then
		err 1 "Could not determine local hostname"
	fi
else
	host=$TGT_HOST
fi
validate_name "host" "${host}"

# Either user a username provided from commandline args or default to the current user
if [ -z "${TGT_USER:-}" ]; then
	user="$(whoami)"
	if [ -z "$user" ]; then
		err 1 "Could not determine local user"
	fi
else
	user=$TGT_USER
fi
validate_name "user" "${user}"

if [ -e "${flake_root}/make-attrs/${user}@${host}.nix" ]; then
	sh "${script_dir}/attrs.sh --write"
fi

# Set user-defined binary cache URLs and Nix trusted public keys from make.env.
# This is set before Nix-Darwin install so it can take advantage of caching.
if is_truthy "${USE_KEYS:-}" || is_truthy "${USE_CACHE:-}"; then
	sh "${script_dir}/set_subs_keys.sh"
fi

# NixGL is a dependency for running Hyprland on non-NixOS system.
logf "DEBUG: hyprland tag %s home_alone %s is_linux %s \n" \
	"$(has_tag "hyprland")" "$(is_truthy "${HOME_ALONE:-}")" "$(is_truthy "${IS_LINUX:-}")"

if has_tag "hyprland" && is_truthy "${HOME_ALONE:-}" && is_truthy "${IS_LINUXL-}"; then
	_launch_nixgl_install
fi

# Install homebrew before Darwin because it can be reference in the Darwin system config
if is_truthy "${USE_HOMEBREW:-}"; then
	_launch_homebrew_install 
fi

# Interactive prompt to avoid manually setting DARWIN_INSTALL
if [ "${UNAME_S:-}" = "Darwin" ]; then
	logf "\nInstall Nix-Darwin? Y/n\n"
	read -r _answer
	case "${_answer}" in
		Y|y|yes|YES) export INSTALL_DARWIN="true"; _launch_darwin_install ;;
		*) logf "\nSkipping Nix-Darwin install.\n" ;;
	esac
fi
