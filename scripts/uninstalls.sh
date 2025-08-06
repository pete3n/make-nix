#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

TARGETS="${1:-uninstall}"
for target in $TARGETS; do
	case "$target" in
	install | home | system | all | test | help)
		logf "%berror:%b uninstall can not be used with any other target.\n" "$RED" "$RESET"
		exit 1
		;;
	esac
done

if [ "${UNAME_S:-}" != "Linux" ] && [ "${UNAME_S:-}" != "Darwin" ]; then
	printf "%binfo%b: unsupported OS: %s\n" "$BLUE" "$RESET" "${UNAME_S:-}"
	exit 1
fi

sh "$SCRIPT_DIR/check_deps.sh" "$TARGETS"

logf "\nDo you wish to continue uninstalling Nix? Y/n\n"
read -r continue
if ! [ "$continue" = "Y" ]; then
	logf "Exiting...\n"
	exit 0
fi

# Derived from: https://nix.dev/manual/nix/2.30/installation/uninstall
logf "\n%b>>> Starting uninstaller...%b\n" "$BLUE" "$RESET"

cleanup_nix_files() {
	is_success=true

	logf "\n%b>>> Cleaning up Nix configuration files...%b\n" "$BLUE" "$RESET"
	backup_files="/etc/zshrc.backup-before-nix /etc/bashrc.backup-before-nix /etc/bash.bashrc.backup-before-nix"

	for backup_file in $backup_files; do
		original_file="${backup_file%.backup-before-nix}"
		if [ -f "$backup_file" ]; then
			printf "\n%binfo:%b restoring %b%s%b to %b%s%b ...\n" \
				"$BLUE" "$RESET" "$MAGENTA" "$backup_file" "$RESET" "$MAGENTA" "$original_file" "$RESET"
			if ! sudo mv "$backup_file" "$original_file"; then
				printf "\n%berror:%b failed to restore: %b%s%b \n" "$RED" "$RESET" "$MAGENTA" "$backup_file" "$RESET"
				is_success=false
			fi
		# No backup
		elif [ -f "$original_file" ] && grep -iq 'Nix' "$original_file"; then
			tmp_file="$(mktemp)"
			sed '/^# Nix$/,/^# End Nix$/d' "$original_file" | tee "$tmp_file" >/dev/null

			if ! cmp -s "$original_file" "$tmp_file"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$original_file" "$RESET"
				sudo cp "$original_file" "$original_file.bak"

				if ! sudo cp "$tmp_file" "$original_file"; then
					is_success=false
					logf "\n%binfo:%b could not modify: %b%s%b\n" \
						"$BLUE" "$RESET" "$MAGENTA" "$original_file" "$RESET"
				fi

				logf "\n%binfo:%b changes made:\n" "$BLUE" "$RESET"
				diff -u "$original_file.bak" "$original_file"
			fi

			rm -f "$tmp_file"
		fi

	done

	if [ "$is_success" = true ]; then
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_multi_user_uninstall_linux() {
	is_success=true
	err_log="$(mktemp)"

	logf "\n%binfo:%b stopping and disabling systemd services ...\n" "$BLUE" "$RESET"
	# Try to stop the service; ignore "not loaded" errors
	if ! sudo systemctl stop nix-daemon.service 2>"$err_log"; then
		if grep -q -e 'not loaded' -e 'not be found' "$err_log"; then
			logf "%binfo:%b nix-daemon.service not loaded; skipping stop.\n" "$BLUE" "$RESET"
		else
			is_success=false
			logf "%berror:%b failed to stop nix-daemon.service\n" "$RED" "$RESET"
			cat "$err_log"
		fi
	fi

	# Try to disable services; ignore "does not exist" errors
	if ! sudo systemctl disable nix-daemon.socket nix-daemon.service 2>"$err_log"; then
		if grep -q -e 'does not exist' -e 'not found' -e 'not loaded' "$err_log"; then
			logf "%binfo:%b nix-daemon services not present; skipping disable.\n" "$BLUE" "$RESET"
		else
			is_success=false
			logf "%berror:%b failed to disable nix-daemon services\n" "$RED" "$RESET"
			cat "$err_log"
		fi
	fi
	sudo systemctl daemon-reload
	: >"$err_log"

	nix_files="/etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-defexpr ~root/.nix-profile ~root/.cache/nix"

	for file in $nix_files; do
		if [ -e "$file" ]; then
			logf "\n%binfo:%b removing: %b%s%b ..." "$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET"

			if ! sudo rm -rf "$file" 2>"$err_log"; then
				if grep -q 'Permission denied' "$err_log"; then
					logf "\n%berror:%b permission denied removing %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
					is_success=false
				elif grep -q 'No such file' "$err_log"; then
					# The file is already gone - not an error condition
					:
				else
					logf "\n%berror:%b unknown error removing %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
					is_success=false
				fi
			fi
		fi

		: >"$err_log"
	done
	rm -f "$err_log"

	logf "\n%binfo:%b removing nixbld users...%b\n" "$BLUE" "$RESET"
	for user in $(seq 1 32); do

		rc=0
		sudo userdel "nixbld$user" 2>/dev/null || rc=$?
		if [ "$rc" -eq 6 ]; then
			# 6 is user doesn't exist — not a failure condition
			continue
		elif [ "$rc" -ne 0 ]; then
			is_success=false
			logf "\n%berror:%b failed to remove user %b%s%b (code %d)\n" \
				"$RED" "$RESET" "$CYAN" "nixbld$user" "$RESET" "$rc"
		fi

	done

	logf "%binfo:%b removing nixbld group...%b\n" "$BLUE" "$RESET"
	rc=0
	sudo groupdel nixbld 2>/dev/null
	rc=$?
	
	if [ "$rc" -eq 6 ]; then
		# Group does not exist — not an error condition
		:
	elif [ "$rc" -ne 0 ]; then
		logf "%berror:%b failed to remove group (code %d)\n" "$RED" "$RESET" "$rc"
		is_success=false
	fi

	if [ "$is_success" = true ]; then
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_multi_user_uninstall_darwin() {
	is_success=true
	err_log="$(mktemp)"

	logf "\n%binfo:%b stopping and removing launchd services ...\n" "$BLUE" "$RESET"
	for plist in org.nixos.nix-daemon org.nixos.darwin-store; do
		plist_path="/Library/LaunchDaemons/$plist.plist"

		if sudo launchctl unload "$plist_path" 2>"$err_log"; then
			logf "%binfo:%b unloaded %s\n" "$BLUE" "$RESET" "$plist_path"
		elif grep -q -e "No such file" -e "not loaded" "$err_log"; then
			logf "%binfo:%b %s not loaded; skipping unload\n" "$BLUE" "$RESET" "$plist_path"
		else
			is_success=false
			logf "%berror:%b failed to unload %s\n" "$RED" "$RESET" "$plist_path"
			cat "$err_log"
		fi

		if sudo rm "$plist_path" 2>"$err_log"; then
			logf "%binfo:%b removed %s\n" "$BLUE" "$RESET" "$plist_path"
		elif grep -q -e "No such file" "$err_log"; then
			logf "%binfo:%b %s not found; skipping removal\n" "$BLUE" "$RESET" "$plist_path"
		else
			is_success=false
			logf "%berror:%b failed to remove %s\n" "$RED" "$RESET" "$plist_path"
			cat "$err_log"
		fi

		: >"$err_log"
	done

	logf "\n%binfo:%b removing nixbld users and group...\n" "$BLUE" "$RESET"
	if ! sudo dscl . -delete /Groups/nixbld 2>/dev/null; then
		logf "%binfo:%b nixbld group not found or already removed.\n" "$BLUE" "$RESET"
	fi

	for user in $(sudo dscl . -list /Users | grep '^_nixbld'); do
		if ! sudo dscl . -delete /Users/"$user" 2>/dev/null; then
			is_success=false
			logf "\n%berror:%b failed to remove user: %b%s%b\n" "$RED" "$RESET" "$CYAN" "$user" "$RESET"
		fi
	done

	FSTAB="/etc/fstab"
	TMP_FSTAB="/tmp/fstab.$$"

	if [ -f "$FSTAB" ]; then
		# Remove lines mounting Nix Store (both UUID and LABEL variants)
		grep -vE '^UUID=.*[[:space:]]/nix[[:space:]]' "$FSTAB" |
			grep -vE '^LABEL=Nix\\040Store[[:space:]]/nix[[:space:]]' >"$TMP_FSTAB"

		if ! cmp -s "$TMP_FSTAB" "$FSTAB"; then
			logf "\n%binfo:%b removing nix entries from fstab...%b\n" "$BLUE" "$RESET"
			sudo cp "$TMP_FSTAB" "$FSTAB"
		fi

		rm -f "$TMP_FSTAB"
	else
		is_success=false
		printf "%bwarning: %b%b/etc/fstab%b does not exist.\n" \
			"$YELLOW" "$RESET" "$MAGENTA" "$RESET"
	fi

	SYNTH_FILE="/etc/synthetic.conf"
	TMP_SYNTH="/tmp/synthetic.conf.$$"

	if [ -f "$SYNTH_FILE" ]; then
		if [ "$(cat "$SYNTH_FILE")" = "nix" ]; then
			logf "\n%binfo:%b removing: %b/etc/synthetic.conf%b" \
				"$BLUE" "$RESET" "$MAGENTA" "$RESET"
			if ! sudo rm "$SYNTH_FILE"; then
				is_success=false
			fi
		else
			# Remove lines that start with 'nix' exactly
			grep -vE '^nix(\s|$)' "$SYNTH_FILE" >"$TMP_SYNTH"
			if ! cmp -s "$TMP_SYNTH" "$SYNTH_FILE"; then
				printf "%binfo:%b removing 'nix' entry from %b/etc/synthetic.conf%b\n" \
					"$BLUE" "$RESET" "$MAGENTA" "$RESET"
				if ! sudo cp "$TMP_SYNTH" "$SYNTH_FILE"; then
					is_success=false
					printf "%binfo:%b failed to modify %b/etc/synthetic.conf%b\n" \
						"$BLUE" "$RESET" "$MAGENTA" "$RESET"
				fi

				rm -f "$TMP_SYNTH"
			fi
		fi
	fi

	nix_files="/etc/nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels ~/.nix-profile ~/.nix-defexpr ~/.nix-channels"
	for file in $nix_files; do
		if [ -e "$file" ]; then
			logf "\n%binfo:%b removing: %b%s%b ..." "$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET"
			if ! sudo rm -rf "$file"; then
				is_success=false
				logf "\n%berror:%b failed to remove %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
			fi
		fi
	done

	logf "\n%binfo:%b removing apfs /nix volume ...\n" "$BLUE" "$RESET"
	if ! sudo diskutil apfs deleteVolume /nix 2>"$err_log"; then
		if grep -q -e "No such file or directory" -e "does not appear to be an APFS volume" "$err_log"; then
			logf "%binfo:%b /nix volume not present or already deleted.\n" "$BLUE" "$RESET"
		else
			is_success=false
			logf "\n%berror:%b failed to remove /nix volume.\n" "$RED" "$RESET"
			cat "$err_log"
		fi
	fi
	rm -f "$err_log"

	if [ "$is_success" = true ]; then
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_single_user_uninstall() {
	is_success=true
	err_log=$(mktemp)

	logf "\n%binfo:%b delete Nix files...\n" "$BLUE" "$RESET"
	nix_files="/nix ~/.nix-channels ~/.nix-defexpr ~/.nix-profile"

	for file in $nix_files; do

		if ! sudo rm -rf "$file" 2>"$err_log"; then
			if grep -q 'Permission denied' "$err_log"; then
				logf "\n%berror:%b permission denied removing %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
				is_success=false
			elif grep -q 'No such file' "$err_log"; then
				# File is already gone, not an error condition.
				:
			else
				logf "\n%berror:%b unknown error removing %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
				is_success=false
			fi
		fi

		: >"$err_log"
	done

	if [ "$is_success" = true ]; then
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

try_installer_uninstall() {
	if [ -x /nix/nix-installer ]; then
		if /nix/nix-installer uninstall; then
			logf "\n%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
			cleanup_nix_files
			exit $?
		fi
	fi
}

if [ "${UNAME_S}" = "Darwin" ]; then
	# Check for Nix-Darwin first because we need to remove it before removing Nix.
	if has_nix_darwin; then
		logf "\n%binfo:%b Nix-darwin detected.\n" "$BLUE" "$RESET"
		if ! sudo darwin-uninstaller; then
			if ! sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller; then
				logf "\n%berror:%b failed to uninstall Nix-Darwin.\n"
				exit 1
			else
				logf "\n%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
			fi
		else
			logf "\n%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
		fi
	fi

	# Check for daemon for multi-user install
	if launchctl list | grep -q '^org.nixos.nix-daemon$'; then
		logf "\n%binfo:%b nix-daemon detected.\n" "$BLUE" "$RESET"
		# Prefer to use uninstallaer if available
		try_installer_uninstall
		nix_multi_user_uninstall_darwin && cleanup_nix_files
		exit $?

	elif has_nix; then
		logf "\n%binfo:%b nix detected.\n" "$BLUE" "$RESET"
		# Prefer to use uninstallaer if available
		try_installer_uninstall
		nix_single_user_uninstall && cleanup_nix_files
		exit $?
	fi
fi

if [ "${UNAME_S}" = "Linux" ]; then
	if systemctl status nix-daemon.service >/dev/null 2>&1; then
		# Prefer to use uninstallaer if available
		try_installer_uninstall
		logf "\n%binfo:%b nix-daemon detected.\n" "$BLUE" "$RESET"
		nix_multi_user_uninstall_linux && cleanup_nix_files
		exit $?

	elif has_nix; then
		logf "\n%binfo:%b nix detected.\n" "$BLUE" "$RESET"
		# Prefer to use uninstallaer if available
		try_installer_uninstall
		nix_single_user_uninstall && cleanup_nix_files
		exit $?
	fi
fi

cleanup_nix_files
exit $?
