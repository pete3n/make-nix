#!/usr/bin/env sh

# Nix Darwin installation script

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

clobber_list="zshenv zshrc bashrc"
restored="false"
restoration_list=""
nix_conf_path="/etc/nix/nix.conf"
nix_conf_backup="${nix_conf_path}.before_darwin"

# Backup config files changed by the installer for restoration
_backup_files() {
  for _file in ${clobber_list}; do
    if [ -e "/etc/${_file}" ]; then
      logf "%b🗂  moving%b %b/etc/%s%b → %b/etc/%s.before_darwin%b\n" \
        "${C_INFO}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
      as_root mv "/etc/${_file}" "/etc/${_file}.before_darwin"
      restoration_list="${restoration_list} ${_file}"
    fi
  done

  if [ -f "${nix_conf_path}" ]; then
		logf "%b🗂  moving%b %b%s%b → %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_PATH}" "${nix_conf_path}" "${C_RST}" "${C_PATH}" "${nix_conf_backup}" "${C_RST}"
    as_root mv "${nix_conf_path}" "${nix_conf_backup}"
    restoration_list="${restoration_list} nix.conf"
  fi
}

# Restore modified configuration files on installation failure
_restore_clobbered_files() {
	if [ "${restored}" = "false" ] && [ -n "${restoration_list}" ]; then
		for _file in ${restoration_list}; do
			if [ -e "/etc/${_file}.before_darwin" ]; then
				logf "%b ↩️%b restoring /etc/%s\n" "${C_INFO}" "${C_RST}" "${_file}"
				if as_root cp "/etc/${_file}.before_darwin" "/etc/${_file}"; then
					as_root rm -f "/etc/${_file}.before_darwin"
				fi
			fi
		done
		restored="true"
	fi
}

_on_signal() {
  _restore_clobbered_files
  cleanup 130 SIGNAL
}

trap '_restore_clobbered_files' EXIT
trap '_on_signal' INT TERM QUIT

_ensure_nix_daemon() {
	if ! [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
		err 1 "nix-daemon binary missing in default profile"
	fi

	as_root launchctl enable system/org.nixos.nix-daemon || true
	as_root launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true
	as_root launchctl kickstart -k system/org.nixos.nix-daemon || true

	# Wait for the socket
	i=1
	while [ $i -lt 20 ] && ! [ -S /nix/var/nix/daemon-socket/socket ]; do
		i=$((i + 1))
		sleep 0.1
	done

	if ! [ -S /nix/var/nix/daemon-socket/socket ]; then
		as_root launchctl print system/org.nixos.nix-daemon | sed -n '1,120p' >&2 || true
		err 1 "nix-daemon socket missing after bootstrap/kickstart"
	fi
}

"$script_dir/attrs.sh" --write

# Re-source env because attrs updates env
# shellcheck disable=SC1090
. "$MAKE_NIX_ENV"

_ensure_nix_daemon

if has_cmd "darwin-rebuild"; then
	logf "\n%binfo:%b Nix-Darwin already appears to be installed. Skipping installation...\n" "${C_CFG}" "${C_RST}"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
	exit 0 # Allow continuing to other targets
fi

"$script_dir/attrs.sh" --check

logf "\n%binfo:%b backing up files before Nix-Darwin install...\n" "${C_INFO}" "${C_RST}"
_backup_files

logf "\n%binfo:%b building Nix-Darwin with command:\n" "${C_INFO}" "${C_RST}"

# Build args
set -- nix build \
  --option experimental-features "nix-command flakes" \
  --max-jobs auto \
  --cores 0 \
  ".#darwinConfigurations.${TGT_USER}@${TGT_HOST}.system"


logf "%b" "${C_CMD}"

# All args except the last
_i=1
_last=$#
for _arg in "$@"; do
  if [ "${_i}" -eq "${_last}" ]; then
    logf "%b%s%b" "${C_CFG}" "${_arg}" "${C_CMD}"
  else
    logf "%s " "${_arg}"
  fi
  _i=$((_i + 1))
done
logf "%b\n" "${C_RST}"

if "$@"; then
	logf "\n%b✓ Nix-Darwin build success.%b\n" "${C_OK}" "${C_RST}"
else
	err 1 "Nix-Darwin build failed. Files will be restored."
fi

logf "\n%binfo:%b activating Nix-Darwin...\n" "${C_CFG}" "${C_RST}"
if as_root ./result/activate; then
	logf "\n%b✓ Nix-Darwin activation success.%b\n" "${C_OK}" "${C_RST}"
	# Prevent restoration on trap
	restoration_list=""
else
	err 1 "Nix-Darwin activation failed. Files will be restored."
fi
