#!/usr/bin/env sh

# Uninstall functions

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: uninstalls.sh failed to source common.sh from %s\n" \
	"${script_dir}/installs.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

# Non-destructive restoration function
_safe_restore() {
  _bak="$1"   # backup file path (source)
  _orig="$2"  # original file path (destination)

  [ -e "${_bak}" ] || return 0

  logf "%b ↩️%b restoring %s\n" "${C_INFO}" "${C_RST}" "${_orig}"

  if as_root cp -p "${_bak}" "${_orig}"; then
    if as_root rm -f "${_bak}"; then
      : # ok
    else
      logf "%b⚠️ warning:%b restored %s but failed to remove backup %s\n" \
        "${C_WARN}" "${C_RST}" "${_orig}" "${_bak}" >&2
    fi
    return 0
  else
    logf "%b⚠️ warning:%b failed to restore %s (leaving backup at %s)\n" \
      "${C_WARN}" "${C_RST}" "${_orig}" "${_bak}" >&2
    return 1
  fi
}

# Retrieve the root user home directory
_get_root_home() {
  if command -v getent >/dev/null 2>&1; then
    getent passwd root | cut -d: -f6
    return
  fi

  # POSIX fallback (always available)
  awk -F: '$1=="root"{print $6}' /etc/passwd
}

# Retrieve the user home (even in sudo command)
_get_user_home() {
  # Prefer the original user when running under sudo
  if [ -n "${SUDO_USER:-}" ]; then
    # POSIX: getent isn't guaranteed everywhere, so use tilde expansion safely via eval
    # shellcheck disable=SC2086
    eval "printf '%s\n' ~${SUDO_USER}"
    return 0
  fi

  # Normal run: $HOME should be correct
  if [ -n "${HOME:-}" ]; then
    printf '%s\n' "${HOME}"
    return 0
  fi

  # Last-resort fallback
  # shellcheck disable=SC2046
  eval "printf '%s\n' ~$(id -un 2>/dev/null || whoami)"
}

_cleanup_nix_files() {
	_is_success="true"

	logf "\n%b>>> Cleaning up Nix configuration files...%b\n" "${C_INFO}" "${C_RST}"
	_backup_files="/etc/profile.d/nix.sh.backup-before-nix /etc/zshrc.backup-before-nix"
	_backup_files="${_backup_files} /etc/bashrc.backup-before-nix /etc/bash.bashrc.backup-before-nix"
	_backup_files="${_backup_files} /etc/zsh/zshrc.backup-before-nix"

	for _backup_file in ${_backup_files}; do
		_original_file="${_backup_file%.backup-before-nix}"

		if [ -f "${_backup_file}" ]; then
			logf "\n%binfo:%b restoring %b%s%b to %b%s%b ...\n" \
				"${C_INFO}" "${C_RST}" "${C_PATH}" "${_backup_file}" "${C_RST}" "${C_PATH}" \
				"${_original_file}" "${C_RST}"
			if ! _safe_restore "${_backup_file}" "${_original_file}"; then
				logf "\n%berror:%b failed to restore: %b%s%b \n" "${C_ERR}" "${C_RST}" \
					"${C_PATH}" "${_backup_file}" "${C_RST}"
				_is_success="false"
			fi

		# No backup
		elif [ -f "${_original_file}" ] && grep -iq 'Nix' "${_original_file}"; then
			_tmp_file="$(mktemp)"
			as_root sh -c "sed '/^# Nix\$/,/^# End Nix\$/d' '${_original_file}' > '${_tmp_file}'"

			if ! cmp -s "${_original_file}" "${_tmp_file}"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "${C_INFO}" "${C_RST}" \
					"${C_PATH}" "${_original_file}" "${C_RST}"
				as_root cp "${_original_file}" "${_original_file}.bak"

				if ! as_root cp "${_tmp_file}" "${_original_file}"; then
					_is_success="false"
					logf "\n%binfo:%b could not modify: %b%s%b\n" \
						"${C_INFO}" "${C_RST}" "${C_PATH}" "${_original_file}" "${C_RST}"
				fi

				logf "\n%binfo:%b changes made:\n" "${C_INFO}" "${C_RST}"
				diff -u "${_original_file}.bak" "${_original_file}" || true
			fi

			rm -f "${_tmp_file}"
		fi
	done

	ca_certs="/etc/ssl/certs/ca-certificates.crt"
	if is_deadlink "${ca_certs}"; then
		as_root rm -f -- "${ca_certs}"
	fi

	if [ "${_is_success}" = "true" ]; then
		logf "%b✅ success:%b all operations completed.\n" "${C_OK}" "${C_RST}"
		return 0
	else
		err 1 "Uninstall cleanup failure: some operations did not complete successfully."
	fi
}

_nix_multi_user_uninstall_linux() {
	_is_success="true"
	_err_log="$(mktemp)"

	logf "\n%binfo:%b stopping and disabling systemd services ...\n" "${C_INFO}" "${C_RST}"
	# Try to stop the service; ignore "not loaded" errors
	if ! as_root systemctl stop nix-daemon.service 2>"${_err_log}"; then
		if grep -q -e 'not loaded' -e 'not be found' "${_err_log}"; then
			logf "%binfo:%b nix-daemon.service not loaded; skipping stop.\n" "${C_INFO}" "${C_RST}"
		else
			_is_success="false"
			logf "%berror:%b failed to stop nix-daemon.service\n" "${C_ERR}" "${C_RST}"
			cat "${_err_log}"
		fi
	fi

	# Try to disable services; ignore "does not exist" errors
	if ! as_root systemctl disable nix-daemon.socket nix-daemon.service 2>"${_err_log}"; then
		if grep -q -e 'does not exist' -e 'not found' -e 'not loaded' "${_err_log}"; then
			logf "%binfo:%b nix-daemon services not present; skipping disable.\n" "${C_INFO}" "${C_RST}"
		else
			_is_success="false"
			logf "%berror:%b failed to disable nix-daemon services\n" "${C_ERR}" "${C_RST}"
			cat "${_err_log}"
		fi
	fi
	as_root systemctl daemon-reload
	: >"${_err_log}"

	_root_home="$(_get_root_home)"
	if [ -z "${_root_home}" ]; then
		err 1 "Could not determine invoking root home directory"
	fi

	case "${_root_home}" in
		/root|/var/root)
			: # explicitly allowed
			;;
		""|"/"|"/var"|"/usr"|"/bin"|"/sbin"|"/etc")
			err 1 "Unsafe root home directory resolved: '${_root_home}'"
			;;
		*)
			err 1 "Unexpected root home directory: '${_root_home}'"
			;;
	esac
	
	_nix_files="/etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf"
	_nix_files="${_nix_files} /nix ${_root_home}/.nix-channels ${_root_home}/.nix-defexpr"
	_nix_files="${_nix_files} ${_root_home}/.nix-profile ${_root_home}/.cache/nix"

	for _file in ${_nix_files}; do
		if [ -e "${_file}" ]; then
			logf "\n%binfo:%b removing: %b%s%b ..." \
				"${C_INFO}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"

			if ! as_root rm -rf "${_file}" 2>"${_err_log}"; then
				if grep -q 'Permission denied' "${_err_log}"; then
					logf "\n%berror:%b permission denied removing %b%s%b\n" \
						"${C_ERR}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
					_is_success="false"
				elif grep -q 'No such file' "${_err_log}"; then
					# The file is already gone - not an error condition
					:
				else
					logf "\n%berror:%b unknown error removing %b%s%b\n" \
						"${C_ERR}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
					_is_success="false"
				fi
			fi
		fi

		: >"${_err_log}"
	done
	rm -f "${_err_log}"

	logf "\n%binfo:%b removing nixbld users...%b\n" "${C_INFO}" "${C_RST}"
	for _user in $(seq 1 32); do
		_rc=0
		as_root userdel "nixbld$_user" 2>/dev/null || _rc=$?
		if [ "${_rc}" -eq 6 ]; then
			# error code 6 is "user doesn't exist" — not a failure condition
			continue
		elif [ "${_rc}" -ne 0 ]; then
			_is_success="false"
			logf "\n%berror:%b failed to remove user %b%s%b (code %d)\n" \
				"${C_ERR}" "${C_RST}" "${C_INFO}" "nixbld${_user}" "${C_RST}" "${_rc}"
		fi
	done

	logf "%binfo:%b removing nixbld group...%b\n" "${C_INFO}" "${C_RST}"
	_rc=0
	as_root groupdel nixbld 2>/dev/null
	_rc=$?

	if [ "${_rc}" -eq 6 ]; then
		# Group does not exist — not an error condition
		:
	elif [ "${_rc}" -ne 0 ]; then
		logf "%berror:%b failed to remove group (code %d)\n" \
			"${C_ERR}" "${C_RST}" "${_rc}"
		_is_success="false"
	fi

	if [ "${_is_success}" = "true" ]; then
		logf "%b✅ success:%b all operations completed.\n" "${C_OK}" "${C_RST}"
		return 0
	else
		logf "%bfailure:%b some operations did not complete successfully.\n" "${C_ERR}" "${C_RST}"
		return 1
	fi
}

_nix_multi_user_uninstall_darwin() {
	_is_success="true"
	_err_log="$(mktemp)"

	logf "\n%binfo:%b stopping and removing launchd services ...\n" "${C_INFO}" "${C_RST}"
	for _plist in org.nixos.nix-daemon org.nixos.darwin-store; do
		_plist_path="/Library/LaunchDaemons/${_plist}.plist"

		if as_root launchctl unload "${_plist_path}" 2>"${_err_log}"; then
			logf "%binfo:%b unloaded %s\n" "${C_INFO}" "${C_RST}" "${_plist_path}"
		elif grep -q -e "No such file" -e "not loaded" "${_err_log}"; then
			logf "%binfo:%b %s not loaded; skipping unload\n" "${C_INFO}" "${C_RST}" "${_plist_path}"
		else
			_is_success="false"
			logf "%berror:%b failed to unload %s\n" "${C_ERR}" "${C_RST}" "${_plist_path}"
			cat "${_err_log}"
		fi

		if as_root rm "${_plist_path}" 2>"${_err_log}"; then
			logf "%binfo:%b removed %s\n" "${C_INFO}" "${C_RST}" "${_plist_path}"
		elif grep -q -e "No such file" "${_err_log}"; then
			logf "%binfo:%b %s not found; skipping removal\n" \
				"${C_INFO}" "${C_RST}" "${_plist_path}"
		else
			_is_success="false"
			logf "%berror:%b failed to remove %s\n" "${C_ERR}" "${C_RST}" "${_plist_path}"
			cat "${_err_log}"
		fi

		: >"${_err_log}"
	done

	logf "\n%binfo:%b removing nixbld users and group...\n" "${C_INFO}" "${C_RST}"
	if ! as_root dscl . -delete /Groups/nixbld 2>/dev/null; then
		logf "%binfo:%b nixbld group not found or already removed.\n" "${C_INFO}" "${C_RST}"
	fi

	for _user in $(as_root dscl . -list /Users | grep '^_nixbld'); do
		if ! as_root dscl . -delete /Users/"${_user}" 2>/dev/null; then
			_is_success="false"
			logf "\n%berror:%b failed to remove user: %b%s%b\n" "${C_ERR}" "${C_RST}" \
				"${C_INFO}" "${_user}" "${C_RST}"
		fi
	done

	_fstab="/etc/fstab"
	_tmp_fstab="/tmp/fstab.$$"

	if [ -f "$_fstab" ]; then
		# Remove lines mounting Nix Store (both UUID and LABEL variants)
		grep -vE '^UUID=.*[[:space:]]/nix[[:space:]]' "${_fstab}" |
			grep -vE '^LABEL=Nix\\040Store[[:space:]]/nix[[:space:]]' >"${_tmp_fstab}"

		if ! cmp -s "${_tmp_fstab}" "${_fstab}"; then
			logf "\n%binfo:%b removing nix entries from fstab...%b\n" "${C_INFO}" "${C_RST}"
			as_root cp "${_tmp_fstab}" "${_fstab}"
		fi

		rm -f "${_tmp_fstab}"
	else
		logf "%bwarning: %b%b/etc/fstab%b does not exist.\n" \
			"${C_WARN}" "${C_RST}" "${C_PATH}" "${C_RST}"
	fi

	_synth_file="/etc/synthetic.conf"
	_tmp_synth="/tmp/synthetic.conf.$$"

	if [ -f "$_synth_file" ]; then
		if [ "$(cat "$_synth_file")" = "nix" ]; then
			logf "\n%binfo:%b removing: %b/etc/synthetic.conf%b" \
				"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
			if ! as_root rm "${_synth_file}"; then
				_is_success="false"
			fi
		else
			# Remove lines that start with 'nix' exactly
			grep -vE '^nix(\s|$)' "${_synth_file}" >"${_tmp_synth}"
			if ! cmp -s "${_tmp_synth}" "${_synth_file}"; then
				logf "%binfo:%b removing 'nix' entry from %b/etc/synthetic.conf%b\n" \
					"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
				if ! as_root cp "${_tmp_synth}" "${_synth_file}"; then
					_is_success="false"
					logf "%binfo:%b failed to modify %b/etc/synthetic.conf%b\n" \
						"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
				fi

				rm "${_tmp_synth}"
			fi
		fi
	fi

	_user_home="$(_get_user_home)"

	case "${_user_home}" in
		""|"/"|"/var"|"/usr"|"/bin"|"/sbin"|"/etc")
			err 1 "Unsafe user home resolved: '${_user_home}'"
			;;
	esac

	[ -d "${_user_home}" ] || err 1 "User home does not exist: '${_user_home}'"
	
	_nix_files="/etc/nix /var/root/.nix-profile /var/root/.nix-defexpr"
	_nix_files="${_nix_files} /var/root/.nix-channels ${_user_home}/.nix-profile"
	_nix_files="${_nix_files} ${_user_home}/.nix-defexpr ${_user_home}/.nix-channels"

	for _file in $_nix_files; do
		if [ -e "$_file" ]; then
			logf "\n%binfo:%b removing: %b%s%b ..." "${C_INFO}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
			if ! as_root rm -rf "$_file"; then
				_is_success="false"
				logf "\n%berror:%b failed to remove %b%s%b\n" "${C_ERR}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
			fi
		fi
	done

	logf "\n%binfo:%b removing apfs /nix volume ...\n" "${C_INFO}" "${C_RST}"
	if ! as_root diskutil apfs deleteVolume /nix 2>"$_err_log"; then
		if grep -q -e "No such file or directory" -e "does not appear to be an APFS volume" "$_err_log"; then
			logf "%binfo:%b /nix volume not present or already deleted.\n" "${C_INFO}" "${C_RST}"
		else
			_is_success="false"
			logf "\n%berror:%b failed to remove /nix volume.\n" "${C_ERR}" "${C_RST}"
			cat "$_err_log"
		fi
	fi
	rm -f "$_err_log"

	if [ "$_is_success" = "true" ]; then
		logf "%b✅ success:%b all operations completed.\n" "${C_OK}" "${C_RST}"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "${C_ERR}" "${C_RST}"
		return 1
	fi
}

_nix_single_user_uninstall() {
	_is_success="true"
	_err_log=$(mktemp)
	_user_home="$(_get_user_home)"

	logf "\n%binfo:%b delete Nix files...\n" "${C_INFO}" "${C_RST}"
	_nix_files="/nix ${_user_home}/.nix-channels ${_user_home}/.nix-defexpr ${_user_home}/.nix-profile"

	for _file in ${_nix_files}; do
		logf "\n%binfo:%b deleting: %b%s%b\n" \
			"${C_INFO}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
		if ! as_root rm -rf "${_file}" 2>"${_err_log}"; then
			if grep -q 'Permission denied' "${_err_log}"; then
				logf "\n%berror:%b permission denied removing %b%s%b\n" \
					"${C_ERR}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
				_is_success="false"
			elif grep -q 'No such file' "${_err_log}"; then
				# File is already gone, not an error condition.
				:
			else
				logf "\n%berror:%b unknown error removing %b%s%b\n" \
					"${C_ERR}" "${C_RST}" "${C_PATH}" "${_file}" "${C_RST}"
				_is_success="false"
			fi
		fi

		: >"${_err_log}"
	done

	if [ "$_is_success" = "true" ]; then
		logf "%b✅ success:%b all operations completed.\n" "${C_OK}" "${C_RST}"
		return 0
	else
		logf "%bfailure:%b some operations did not complete successfully.\n" "${C_ERR}" "${C_RST}"
		return 1
	fi
}

_try_installer_uninstall() {
	if [ -x /nix/nix-installer ]; then
		if /nix/nix-installer uninstall; then
			logf "\n%b✅ success:%b uninstall complete.\n" "${C_OK}" "${C_RST}"
			_cleanup_nix_files
			exit $?
		fi
	fi
}

TARGETS="${1:-uninstall}"
for target in $TARGETS; do
	case "$target" in
	install | home | system | all | test | help)
		err 1 "uninstall can not be used with any other target."
		;;
	esac
done

if [ "${UNAME_S:-}" != "Linux" ] && [ "${UNAME_S:-}" != "Darwin" ]; then
	err 1 "unsupported OS: ${C_INFO}${UNAME_S:-}${C_RST}"
fi

logf "\nDo you wish to continue uninstalling Nix? Y/n\n"
read -r answer
case "${answer}" in
  Y|y|yes|YES) ;;
  *) logf "Exiting...\n"; exit 0 ;;
esac

# Derived from: https://nix.dev/manual/nix/2.30/installation/uninstall
logf "\n%b>>> Starting uninstaller...%b\n" "${C_INFO}" "${C_RST}"

# Check for Nix-Darwin first because we need to remove it before removing Nix.
if [ "${UNAME_S:-}" = "Darwin" ]; then
	if ! has_cmd "darwin-uninstaller"; then
		source_darwin
	fi

	if has_cmd "darwin-uninstaller"; then
		as_root darwin-uninstaller
	else
		set -- nix run nix-darwin#darwin-uninstaller
		as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"
	fi 

	if has_nix_daemon || nix_daemon_socket_up; then
		logf "\n%binfo:%b nix-daemon (multi-user) detected.\n" "${C_INFO}" "${C_RST}"
		_try_installer_uninstall
		_nix_multi_user_uninstall_darwin && _cleanup_nix_files
		exit $?
	elif has_cmd "nix"; then
		logf "\n%binfo:%b nix CLI detected (likely single-user).\n" "${C_INFO}" "${C_RST}"
		_try_installer_uninstall
		_nix_single_user_uninstall && _cleanup_nix_files
		exit $?
	else
		logf "\n%binfo:%b Nix not detected; nothing to uninstall.\n" "${C_INFO}" "${C_RST}"
		exit 0
	fi
fi

if [ "${UNAME_S:-}" = "Linux" ]; then
  if has_nix_daemon || nix_daemon_socket_up; then
    logf "\n%binfo:%b nix-daemon (multi-user) detected.\n" "${C_INFO}" "${C_RST}"
    _nix_multi_user_uninstall_linux && _cleanup_nix_files
    exit $?
  elif has_cmd "nix"; then
    logf "\n%binfo:%b nix CLI detected (likely single-user).\n" "${C_INFO}" "${C_RST}"
    _nix_single_user_uninstall && _cleanup_nix_files
    exit $?
  else
    logf "\n%binfo:%b Nix not detected; nothing to uninstall.\n" "${C_INFO}" "${C_RST}"
    exit 0
  fi
fi

_cleanup_nix_files
exit $?
