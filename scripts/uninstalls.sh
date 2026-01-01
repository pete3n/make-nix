#!/usr/bin/env sh

# Uninstall functions

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: uninstalls.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'rm -f "${_err_log:-}"' EXIT 2>/dev/null || :
trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

# Stop Nix and Nix-Darwin services
# Requires: id, mktemp, awk, grep, launchctl|systemctl
# $1: Operating mode - nix|darwin
_stop_nix_services() {
	_mode="${1}"
	_uid="$(id -u)"
	_err_log="$(mktemp)"

	case "${_mode}" in
		nix|darwin) : ;;
		*)
			logf "%berror:%b invalid mode for _stop_nix_services: %s\n" \
				"${C_ERR}" "${C_RST}" "${_mode}" >&2
			rm -f -- "${_err_log}"
			return 1
			;;
	esac

	if [ "${_mode}" = "nix" ]; then
		logf "\n%binfo:%b stopping and disabling systemd services ...\n" \
			"${C_INFO}" "${C_RST}"

		# Stop daemon (ignore if not running)
		if as_root systemctl is-active --quiet nix-daemon.service 2>/dev/null; then
			if ! as_root systemctl stop nix-daemon.service 2>"${_err_log}"; then
				logf "%berror:%b failed to stop nix-daemon.service\n%s\n" \
					"${C_ERR}" "${C_RST}" "$(tail -n 50 "${_err_log}")" >&2
				rm -f -- "${_err_log}"
				return 1
			fi
		else
			logf "%binfo:%b nix-daemon.service not active; skipping stop.\n" \
				"${C_INFO}" "${C_RST}"
		fi

		# Disable socket + service if present
		for _unit in nix-daemon.socket nix-daemon.service; do
			if as_root systemctl list-unit-files "${_unit}" >/dev/null 2>&1; then
				if ! as_root systemctl disable "${_unit}" 2>"${_err_log}"; then
					logf "%berror:%b failed to disable %s\n%s\n" \
						"${C_ERR}" "${C_RST}" "${_unit}" "$(tail -n 50 "${_err_log}")" >&2
					rm -f -- "${_err_log}"
					return 1
				fi
			else
				logf "%binfo:%b %s not present; skipping disable.\n" \
					"${C_INFO}" "${C_RST}" "${_unit}"
			fi
		done
		as_root systemctl daemon-reload
	fi

	if [ "${_mode}" = "darwin" ]; then
		logf "\n%binfo:%b stopping org.nixos.* launchd jobs...\n" "${C_INFO}" "${C_RST}"

		# Collect currently-known org.nixos.* labels (best-effort)
		_labels="$(launchctl list 2>/dev/null \
			| awk 'NF{print $NF}' \
			| grep '^org\.nixos\.' || true)"

		# Disable labels (prevents immediate restart)
		for _lbl in ${_labels}; do
			launchctl disable "gui/${_uid}/${_lbl}" 2>/dev/null || true
			as_root launchctl disable "system/${_lbl}" 2>/dev/null || true
		done

		# Bootout user agents
		for _base in "$HOME/Library/LaunchAgents" "/Library/LaunchAgents"; do
			for _plist in "${_base}"/org.nixos.*.plist; do
				[ -f "${_plist}" ] || continue
				launchctl bootout "gui/${_uid}" "${_plist}" 2>"${_err_log}" || true
			done
		done

		# Bootout system daemons
		for _plist in /Library/LaunchDaemons/org.nixos.*.plist; do
			[ -f "${_plist}" ] || continue
			as_root launchctl bootout system "${_plist}" 2>"${_err_log}" || true
		done
	fi

	rm -f -- "${_err_log}"
	return 0
}

_cleanup_nix_backups() {
	logf "\n%b>>> Cleaning up Nix configuration files...%b\n" "${C_INFO}" "${C_RST}"
	_backup_files="/etc/profile.d/nix.sh.backup-before-nix /etc/zshrc.backup-before-nix"
	_backup_files="${_backup_files} /etc/bashrc.backup-before-nix /etc/bash.bashrc.backup-before-nix"
	_backup_files="${_backup_files} /etc/zsh/zshrc.backup-before-nix"
	_ca_certs="/etc/ssl/certs/ca-certificates.crt"
	_rc=0

	for _backup_file in ${_backup_files}; do
		_original_file="${_backup_file%.backup-before-nix}"

		if [ -f "${_backup_file}" ]; then
			logf "\n%binfo:%b restoring %b%s%b to %b%s%b ...\n" \
				"${C_INFO}" "${C_RST}" "${C_PATH}" "${_backup_file}" "${C_RST}" "${C_PATH}" \
				"${_original_file}" "${C_RST}"
			if ! safe_restore "${_backup_file}" "${_original_file}"; then
				logf "\n%berror:%b failed to restore: %b%s%b \n" "${C_ERR}" "${C_RST}" \
					"${C_PATH}" "${_backup_file}" "${C_RST}"
				_rc=1
			fi

		# No backup
		elif [ -f "${_original_file}" ] && grep -iq 'Nix' "${_original_file}"; then
			_tmp_fstab="$(mktemp)"
			as_root sh -c "sed '/^# Nix\$/,/^# End Nix\$/d' '${_original_file}' > '${_tmp_fstab}'"

			if ! cmp -s "${_original_file}" "${_tmp_fstab}"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "${C_INFO}" "${C_RST}" \
					"${C_PATH}" "${_original_file}" "${C_RST}"
				as_root cp "${_original_file}" "${_original_file}.bak"

				if ! as_root cp "${_tmp_fstab}" "${_original_file}"; then
					logf "\n%binfo:%b could not modify: %b%s%b\n" \
						"${C_INFO}" "${C_RST}" "${C_PATH}" "${_original_file}" "${C_RST}"
					_rc=1
				fi

				logf "\n%binfo:%b changes made:\n" "${C_INFO}" "${C_RST}"
				diff -u "${_original_file}.bak" "${_original_file}" || true
			fi
			rm -f -- "${_tmp_fstab}"
		fi
	done

	if is_deadlink "${_ca_certs}"; then
		as_root rm -f -- "${_ca_certs}"
	fi

	if [ ${_rc} -eq 0 ]; then
		logf "%b✅ success:%b all operations completed.\n" "${C_OK}" "${C_RST}"
	else
		logf "%b error:%b some cleanup operations failed to complete.\n" "${C_ERR}" "${C_RST}"
	fi

	return ${_rc}
}

_del_nix_files() {
	_mode="${1}"
	_err_log="$(mktemp)"
	_rc=0

	case "${_mode}" in
		nix|darwin) : ;;
		*)
			logf "%berror:%b invalid mode for _del_nix_users: %s\n" \
				"${C_ERR}" "${C_RST}" "${_mode}" >&2
			rm -f -- "${_err_log}"
			return 1
			;;
	esac

	_user_home="$(get_user_home)"
	if [ -z "${_user_home}" ]; then
		err 1 "Could not determine user home directory"
	fi
	case "${_user_home}" in
		""|"/"|"/var"|"/usr"|"/bin"|"/sbin"|"/etc")
			err 1 "Unsafe user home resolved: '${_user_home}'"
			;;
	esac

	_root_home="$(get_root_home)"
	if [ -z "${_root_home}" ]; then
		err 1 "Could not determine root home directory"
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

	_nix_darwin_files="/etc/nix /var/root/.nix-profile /var/root/.nix-defexpr"
	_nix_darwin_files="${_nix_darwin_files} /var/root/.nix-channels ${_user_home}/.nix-profile"
	_nix_darwin_files="${_nix_darwin_files} ${_user_home}/.nix-defexpr ${_user_home}/.nix-channels"

	_nix_files="/etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf"
	_nix_files="${_nix_files} /nix ${_root_home}/.nix-channels ${_root_home}/.nix-defexpr"
	_nix_files="${_nix_files} ${_root_home}/.nix-profile ${_root_home}/.cache/nix"

	if [ "${_mode}" = "nix" ]; then
		for _file in ${_nix_files}; do
			if [ -e "${_file}" ]; then
				logf "\n%binfo:%b removing: %b%s%b ..." \
					"${C_INFO}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"

				if ! as_root rm -rf -- "${_file}" 2>"${_err_log}"; then
					if tail -n 50 "${_err_log}" | grep -q 'Permission denied'; then
						logf "\n%berror:%b permission denied removing %b%s%b\n" \
							"${C_ERR}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
						_rc=1
					elif tail -n 50 "${_err_log}" | grep -q 'No such file'; then
						: # File already deleted. Not an error.
					else
						logf "\n%berror:%b unknown error removing %b%s%b\n" \
							"${C_ERR}" "${C_RST}" "${C_PATH}" "$_file" "${C_RST}"
						_rc=1
					fi
				fi
			fi
		done
	fi

	if [ "${_mode}" = "darwin" ]; then
		for _file in ${_nix_darwin_files}; do
			if [ -e "${_file}" ]; then
				logf "\n%binfo:%b removing: %b%s%b ..." "${C_INFO}" "${C_RST}" \
					"${C_PATH}" "${_file}" "${C_RST}"
				if ! as_root rm -rf -- "${_file}"; then
					_rc=1
					logf "\n%berror:%b failed to remove %b%s%b\n" "${C_ERR}" "${C_RST}" \
						"${C_PATH}" "${_file}" "${C_RST}"
				fi
			fi
		done
	fi

	rm -f -- "${_err_log}"
	return "${_rc}"
}

_del_nix_users() {
	_mode="${1}"
	_rc=0

	case "${_mode}" in
		nix|darwin) : ;;
		*)
			logf "%berror:%b invalid mode for _del_nix_users: %s\n" \
				"${C_ERR}" "${C_RST}" "${_mode}" >&2
			rm -f -- "${_err_log}"
			return 1
			;;
	esac

	if [ "${_mode}" = "nix" ]; then
		logf "\n%binfo:%b removing nixbld users...%b\n" "${C_INFO}" "${C_RST}"

		_user=1
		while [ "${_user}" -le 32 ]; do
			_rc=0
			as_root userdel "nixbld${_user}" 2>/dev/null || _rc=$?

			if [ "${_rc}" -eq 6 ]; then
				_user=$(( _user + 1 ))
				continue
			elif [ "${_rc}" -ne 0 ]; then
				logf "\n%berror:%b failed to remove user %b%s%b (code %d)\n" \
					"${C_ERR}" "${C_RST}" "${C_INFO}" "nixbld${_user}" "${C_RST}" "${_rc}"
				rm -f -- "${_err_log}"
				return 1
			fi

			_user=$(( _user + 1 ))
		done

		logf "%binfo:%b removing nixbld group...%b\n" "${C_INFO}" "${C_RST}"
		as_root groupdel nixbld 2>/dev/null
		_rc=$?

		if [ "${_rc}" -eq 6 ]; then
			# Group does not exist — not an error condition
			:
		elif [ "${_rc}" -ne 0 ]; then
			logf "%berror:%b failed to remove group (code %d)\n" \
				"${C_ERR}" "${C_RST}" "${_rc}"
			rm -f -- "${_err_log}"
			return 1
		fi
	fi

	if [ "${_mode}" = "darwin" ]; then
		for _user in $(as_root dscl . -list /Users | grep '^_nixbld'); do
			if ! as_root dscl . -delete /Users/"${_user}" 2>/dev/null; then
				logf "\n%berror:%b failed to remove user: %b%s%b\n" "${C_ERR}" "${C_RST}" \
					"${C_INFO}" "${_user}" "${C_RST}"
			fi
		done

		logf "\n%binfo:%b removing nixbld users and group...\n" "${C_INFO}" "${C_RST}"
		if ! as_root dscl . -delete /Groups/nixbld 2>/dev/null; then
			logf "%binfo:%b nixbld group not found or already removed.\n" "${C_INFO}" "${C_RST}"
		fi
	fi

	return 0
}

# Requires: lsof, awk, sort, head, diskutil, apfs, grep, cat, rm
_del_darwin_store() {
	# Return the APFS "Volume Disk" device for a mountpoint, e.g. "disk3s7"
	# Echoes nothing if not an APFS volume (or not present).
	_get_apfs_vol() {
		_mnt="${1}"

		# Prefer a direct mount lookup (fast, no recursion)
		# mount output: /dev/disk3s7 on /nix (apfs, local, ...)
		_dev="$(mount | awk -v m="${_mnt}" '$3 == m { sub("^/dev/","",$1); print $1; exit }')"
		[ -n "${_dev}" ] || return 0

		# Confirm it’s APFS and extract "Volume Disk" from diskutil info
		diskutil info "${_dev}" 2>/dev/null \
		| awk -F': *' '
				$1=="Type (Bundle)" && $2!="apfs" { exit }
				$1=="File System Personality" && $2!="APFS" { exit }
				$1=="Volume Disk" { print $2; exit }
			'
	}

	_del_apfs_vol() {
		_mnt=$1

		_vdisk="$(_get_apfs_vol "$_mnt")"
		if [ -z "${_vdisk}" ]; then
			# Not mounted as APFS at that mountpoint (already deleted or not APFS)
			return 0
		fi

		# Delete by volume disk ID, not by path
		as_root diskutil apfs deleteVolume "${_vdisk}" >/dev/null 2>&1
	}

	_is_mountpoint() { mount | awk -v m="$1" '$3==m{found=1} END{exit !found}'; }

	if has_cmd lsof; then
		# Best-effort visibility: don't fail the uninstall because of lsof output
		logf "\n%binfo:%b Checking for open files in /nix...\n" "${C_INFO}" "${C_RST}"
		_open="$(
			lsof -nP 2>/dev/null \
			| awk 'NF>=9 && $9 ~ "^/nix/" { print $1, $2 }' \
			| sort -u | head -n 10 || true
		)"
		if [ -n "${_open}" ]; then
			logf "%bwarning:%b processes still appear to have files open under /nix:\n%s\n" \
				"${C_WARN}" "${C_RST}" "${_open}" >&2
			return 1
		fi
	fi

	if _is_mountpoint /nix; then
		if ! _del_apfs_vol /nix; then
			logf "\n%berror:%b failed to remove /nix APFS volume.\n" "${C_ERR}" "${C_RST}"
			return 1
		fi
	else
		as_root rm -rf -- "/nix" 2>/dev/null || true
	fi

	return 0
}

_cleanup_darwin_mnt() {
	_rc=0
	_fstab="/etc/fstab"
	_tmp_fstab="$(mktemp)"
	_synth_file="/etc/synthetic.conf"
	_tmp_synth="$(mktemp)"

	if [ -f "$_fstab" ]; then
		# Remove lines mounting Nix Store (both UUID and LABEL variants)
		grep -vE '^UUID=.*[[:space:]]/nix[[:space:]]' "${_fstab}" |
			grep -vE '^LABEL=Nix\\040Store[[:space:]]/nix[[:space:]]' >"${_tmp_fstab}"

		if ! cmp -s "${_tmp_fstab}" "${_fstab}"; then
			logf "\n%binfo:%b removing nix entries from fstab...%b\n" "${C_INFO}" "${C_RST}"
			as_root cp "${_tmp_fstab}" "${_fstab}"
		fi
		rm -f -- "${_tmp_fstab}"
	else
		logf "%bwarning: %b%b/etc/fstab%b does not exist.\n" \
			"${C_WARN}" "${C_RST}" "${C_PATH}" "${C_RST}"
	fi

	if [ -f "$_synth_file" ]; then
		if as_root sh -c "grep -qE '^nix([[:space:]]|\$)' /etc/synthetic.conf 2>/dev/null"; then
			logf "\n%binfo:%b removing: %b/etc/synthetic.conf%b\n" \
				"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
			if ! as_root rm -- "${_synth_file}"; then
				_rc=1
			fi
		else
			# Remove lines that start with 'nix' exactly
			grep -vE '^nix([[:space:]]|$)' "${_synth_file}" >"${_tmp_synth}"
			if ! cmp -s "${_tmp_synth}" "${_synth_file}"; then
				logf "%binfo:%b removing 'nix' entry from %b/etc/synthetic.conf%b\n" \
					"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
				if ! as_root cp "${_tmp_synth}" "${_synth_file}"; then
					_rc=1
					logf "%binfo:%b failed to modify %b/etc/synthetic.conf%b\n" \
						"${C_INFO}" "${C_RST}" "${C_PATH}" "${C_RST}"
				fi
			fi
		fi
	fi
	
	rm -f -- "${_tmp_synth}" "${_tmp_fstab}"
	return "${_rc}"
}

for _goal in "$@"; do
	case "${_goal}" in
		all|install|check|check-home|check-system|build|build-home|build-system \
			|switch|switch-home|switch-system|update|test|help|clean)
			err 1 "uninstall cannot be used with: ${_goal}"
			;;
	esac
done

uname_s="$(uname -s)"
case "${uname_s}" in
	Linux)
		logf "\nDo you wish to continue uninstalling Nix? Y/n\n"
		read -r _answer
		case "${_answer}" in
			Y|y|yes|YES) ;;
			*) logf "Exiting...\n"; exit 0 ;;
		esac

		_rc=0
		{ has_nix_daemon || nix_daemon_socket_up; } && \
			_multi_user="true" || _multi_user="false"

		# Prefer nix uninstaller if available
		if [ -x /nix/nix-installer ]; then
			if ! /nix/nix-installer uninstall; then _rc=1; fi
			if ! _cleanup_nix_backups; then _rc=1; fi
			exit ${_rc}
		fi

		# Manual multi-user nix uninstall 
		if [ "${_multi_user}" = "true" ]; then
			if ! _stop_nix_services "nix"; then _rc=1; fi
			if ! _del_nix_files "nix"; then _rc=1; fi
			if ! _del_nix_users "nix"; then _rc=1; fi
			if ! _cleanup_nix_backups; then _rc=1; fi
			exit ${_rc}
		fi

		if [ "${_multi_user}" = "false" ]; then
			logf "Single user Nix removal.\n"
			as_root rm -rf -- "/nix"
			_cleanup_nix_backups || _rc=1
			exit ${_rc}
		fi
		;;
	Darwin)  
		_rc=0
		_uninstall_darwin="false"

		# Detect Nix-Darwin by confirming the Nix daemon is present
		{ has_nix_daemon || nix_daemon_socket_up; } && \
			_nix_darwin="true" || _nix_darwin="false"

		if [ "${_nix_darwin}" = "true" ]; then
			logf "\nDo you wish to continue uninstalling Nix-Darwin? Y/n\n"
			read -r _answer
			case "${_answer}" in
				Y|y|yes|YES) _uninstall_darwin="true" ;;
				*) _uninstall_darwin="false" ;;
			esac
		fi

		# Attempt the native uninstaller first
		if [ "${_uninstall_darwin}" = "true" ] && has_cmd "darwin-uninstaller"; then
			if ! as_root darwin-uninstaller; then _rc=1; fi
		elif [ "${_uninstall_darwin}" = "true" ]; then
			if ! as_root nix --extra-experimental-features "nix-command flakes" \
				run nix-darwin#darwin-uninstaller; then _rc=1; 
			fi
		fi

		logf "\nDo you wish to continue uninstalling Nix? Y/n\n"
		read -r _answer
		case "${_answer}" in
			Y|y|yes|YES) ;;
			*) logf "Exiting...\n"; exit ${_rc} ;;
		esac

		# Prefer nix uninstaller if available
		if [ -x /nix/nix-installer ]; then
			if ! /nix/nix-installer uninstall; then _rc=1; fi
			exit ${_rc}
		fi

		# Manual multi-user nix uninstall 
		if ! _cleanup_nix_backups; then _rc=1; fi
		if ! _stop_nix_services "darwin"; then _rc=1; fi
		if ! _del_nix_users "darwin"; then _rc=1; fi
		if ! _cleanup_darwin_mnt; then _rc=1; fi
		if ! _del_nix_files "darwin"; then _rc=1; fi
		if ! _del_darwin_store; then _rc=1; fi
		exit ${_rc}

		;;
	*) err 1 "unsupported OS: ${C_INFO}${uname_s}${C_RST}" ;;
esac
