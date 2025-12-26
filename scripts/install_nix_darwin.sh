#!/usr/bin/env sh

# Nix Darwin installation script

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh"

clobber_list="/etc/zshenv /etc/zshrc /etc/bashrc /etc/nix/nix.conf"
backup_ext="before_darwin"
restored="false"
restoration_list=""

# Restore modified configuration files on installation failure
_restore_files() {
	[ "${restored}" = "true" ] && return 0
	[ -z "${restoration_list}" ] && { restored="true"; return 0; }

	_failed=0

	for _file in ${restoration_list}; do
		_bak="${_file}.${backup_ext}" 
		# No backup to restore
		[ -e "${_bak}" ] || continue 
		logf "%b ↩️%b restoring %s\n" "${C_INFO}" "${C_RST}" "${_file}"

		# Try restore 
		if as_root cp "${_bak}" "${_file}"; then
			# Only remove backup on success
			as_root rm -f "${_file}.${backup_ext}"
		else
			_failed=1
			logf "%b⚠️ warning:%b failed to restore %s (leaving backup at %s)\n" \
      "${C_WARN}" "${C_RST}" "${_file}" "${_bak}" >&2
		fi
	done
	restored="true"
	
	return "${_failed}"
}

_on_signal() {
  _restore_files
  cleanup 130 SIGNAL
}

trap '_restore_files' EXIT
trap '_on_signal' INT TERM QUIT

"$script_dir/attrs.sh" --write

# Re-source env because attrs updates env
# shellcheck disable=SC1090
. "$MAKE_NIX_ENV"

# Ensure the Nix Daemon exists and is running
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
	err 1 "nix-daemon could not be started"
fi

if has_cmd "darwin-rebuild"; then
	logf "\n%binfo:%b Nix-Darwin already appears to be installed. Skipping installation...\n" "${C_CFG}" "${C_RST}"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
	exit 0 # Allow continuing to other targets
fi

"$script_dir/attrs.sh" --check

# Backup config files changed by the installer for restoration
logf "\n%binfo:%b backing up files before Nix-Darwin install...\n" "${C_INFO}" "${C_RST}"
  for _file in ${clobber_list}; do
    if [ -e "${_file}" ]; then
      logf "%b🗂  moving%b %b%s → %s.%s%b\n" \
        "${C_INFO}" "${C_RST}" "${C_PATH}" "${_file}" "${_file}" "${backup_ext}" "${C_RST}"
      as_root mv "${_file}" "${_file}.${backup_ext}"
      restoration_list="${restoration_list} ${_file}"
    fi
  done

logf "\n%binfo:%b building Nix-Darwin with command:\n" "${C_INFO}" "${C_RST}"

# Build command args
set -- nix build \
  --option experimental-features "nix-command flakes" \
  --max-jobs auto \
  --cores 0 \
  ".#darwinConfigurations.${TGT_USER}@${TGT_HOST}.system"

logf "%b" "${C_CMD}"

# Print the command arguments, then the configuration arg
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
