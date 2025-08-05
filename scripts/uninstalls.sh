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
	nix_files="/etc/bash.bashrc /etc/bashrc /etc/profile /etc/zsh/zshrc /etc/zshrc"

	for file in $nix_files; do
		if [ -f "$file" ] && grep -iq 'Nix' "$file"; then
			tmp_file="$(mktemp)"
			sed '/^# Nix$/,/^# End Nix$/d' "$file" | sudo tee "$tmp_file" >/dev/null
			if ! cmp -s "$file" "$tmp_file"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$file" "$RESET"
				sudo cp "$file" "$file.bak"
				if ! sudo cp "$tmp_file" "$file"; then
					is_success=false
					logf "\n%binfo:%b could not modify: %b%s%b\n" \
						"$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET"
				fi
				logf "\n%binfo:%b removed:\n"
				diff -u "$file.bak" "$file"
			fi
			rm -f "$tmp_file"
		fi
	done

	if [ -f "$HOME/.profile" ] && grep -iq "nix" "$HOME/.profile"; then
		logf "%binfo: %b you may want remove references to Nix in %b%s%b" \
			"$BLUE" "$RESET" "$MAGENTA" "$HOME/.profile" "$RESET"
	fi

	if [ "$is_success" = true ]; then
		is_success=true
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_multi_user_uninstall_linux() {
	is_success=true

	logf "\n%binfo:%b stopping and disabling nix-daemon.service ..." "$BLUE" "$RESET"
	if ! sudo systemctl stop nix-daemon.service; then
		is_success=false
	fi
	if ! sudo systemctl disable nix-daemon.socket nix-daemon.service; then
		is_success=false
	fi
	sudo systemctl daemon-reload

	nix_files="/etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-defexpr ~root/.nix-profile ~root/.cache/nix"

	for file in $nix_files; do
		if [ -e "$file" ]; then
			logf "\n%binfo:%b removing: %b%s%b ..." "$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET"
			if ! sudo rm -rf file; then
				is_success=false
				logf "\n%berror:%b failed to remove %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
			fi
		fi
	done

	logf "\n%binfo:%b removing nixbld users...%b\n" "$BLUE" "$RESET"
	for user in $(seq 1 32); do
		if ! sudo userdel nixbld"$user"; then
			is_success=false
			logf "\n%berror:%b failed to remove user: %b%s%b\n" "$RED" "$RESET" "$CYAN" "$user" "$RESET"
		fi
	done

	logf "%binfo:%b removing nixbld group...%b\n" "$BLUE" "$RESET"
	if ! sudo groupdel nixbld; then
		logf "%berror:%b failed to remove group.\n" "$RED" "$RESET"
	fi

	if [ "$is_success" = true ]; then
		is_success=true
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_multi_user_uninstall_darwin() {
	is_success=true
	backup_files="/etc/zshrc.backup-before-nix /etc/bashrc.backup-before-nix /etc/bash.bashrc.backup-before-nix"

	for file in $backup_files; do
		original_file="${file%.backup-before-nix}"
		if [ -f "$file" ]; then
			printf "\n%binfo:%b restoring %b%s%b to %b%s%b ...\n" \
				"$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET" "$MAGENTA" "$original_file" "$RESET"
			if ! sudo mv "$file" "$original_file"; then
				printf "\n%berror:%b failed to restore: %b%s%b \n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
				is_success=false
			fi
		# No backup
		elif [ -f "$original_file" ] && grep -iq 'Nix' "$original_file"; then
			tmp_file="$(mktemp)"
			sed '/^# Nix$/,/^# End Nix$/d' "$file" sudo tee "$tmp_file"
			if ! cmp -s "$original_file" "$tmp_file"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$original_file" "$RESET"
				sudo cp "$original_file" "$file.bak"
				sudo cp "$tmp_file" "$original_file"
				logf "%binfo:%b removed:\n"
				diff -u "$file.bak" "$original_file"
			fi
			rm -f "$tmp_file"
		fi

	done

	logf "\n%binfo:%b stopping and disabling nix-daemon.service ..." "$BLUE" "$RESET"
	if ! sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist; then
		is_success=false
	fi
	if ! sudo rm /Library/LaunchDaemons/org.nixos.nix-daemon.plist; then
		is_success=false
	fi
	if ! sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist; then
		is_success=false
	fi
	if ! sudo rm /Library/LaunchDaemons/org.nixos.darwin-store.plist; then
		is_success=false
	fi

	logf "\n%binfo:%b removing nixbld users...%b\n" "$BLUE" "$RESET"
	sudo dscl . -delete /Groups/nixbld
	for user in $(sudo dscl . -list /Users | grep _nixbld); do
		if ! sudo dscl . -delete /Users/"$user"; then
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
			if ! sudo rm -rf file; then
				is_success=false
				logf "\n%berror:%b failed to remove %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
			fi
		fi
	done

	logf "\n%binfo:%b removing apfs /nix volume ...\n" "$BLUE" "$RESET"
	if ! sudo diskutil apfs deleteVolume /nix; then
		is_success=false
		logf "\n%berror:%b failed to remove /nix volume.\n" "$RED" "$RESET"
	fi

	if [ "$is_success" = true ]; then
		is_success=true
		logf "%b✅ success:%b all operations completed.\n" "$GREEN" "$RESET"
		return 0
	else
		logf "%b❌failure:%b some operations did not complete successfully.\n" "$RED" "$RESET"
		return 1
	fi
}

nix_single_user_uninstall() {
	is_success=true
	nix_files="/nix ~/.nix-channels ~/.nix-defexpr ~/.nix-profile"

	for file in $nix_files; do
		if [ -f "$file" ]; then
			logf "\n%binfo:%b removing file: %b%s%b ..." "$BLUE" "$RESET" "$MAGENTA" "$file" "$RESET"
			if ! sudo rm -rf file; then
				is_success=false
				logf "\n%berror:%b failed to remove %b%s%b\n" "$RED" "$RESET" "$MAGENTA" "$file" "$RESET"
			fi
		fi
	done
	if [ "$is_success" = true ]; then
		is_success=true
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
		logf "%\binfo:%b nix-daemon detected.\n" "$BLUE" "$RESET"
		try_installer_uninstall
		nix_multi_user_uninstall_darwin && cleanup_nix_files
		exit $?

	elif check_for_nix no-exit; then
		logf "%\binfo:%b nix detected.\n" "$BLUE" "$RESET"
		try_installer_uninstall
		nix_single_user_uninstall && cleanup_nix_files
		exit $?
	fi
fi

if [ "${UNAME_S}" = "Linux" ]; then
	if systemctl status nix-daemon.service >/dev/null 2>&1; then
		logf "%\binfo:%b nix-daemon detected.\n" "$BLUE" "$RESET"
		nix_multi_user_uninstall_linux && cleanup_nix_files
		exit $?

	elif check_for_nix no-exit; then
		logf "%\binfo:%b nix detected.\n" "$BLUE" "$RESET"
		try_installer_uninstall
		nix_single_user_uninstall && cleanup_nix_files
		exit $?
	fi
fi

cleanup_nix_files
exit $?
