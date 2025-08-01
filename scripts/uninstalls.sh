#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

TARGETS="${1:-uninstall}"
sh "$SCRIPT_DIR/check_deps.sh" "$TARGETS"

for target in $TARGETS; do
	case "$target" in
	install | home | system | all | test | help)
		logf "%berror:%b uninstall can not be used with any other target.\n" "$RED" "$RESET"
		exit 1
		;;
	esac
done

logf "%b>>> Starting uninstaller...%b\n" "$BLUE" "$RESET"
if has_nix_darwin; then
	logf "%binfo:%b Nix-darwin detected.\n" "$BLUE" "$RESET"
	if ! sudo darwin-uninstaller; then
		if ! sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller; then
			logf "%berror:%b failed to uninstall Nix-Darwin.\n"
			exit 1
		else
			logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
		fi
	else
		logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
	fi
fi

nix_multi_user_uninstall() {
	sudo systemctl stop nix-daemon.service
	sudo systemctl disable nix-daemon.socket nix-daemon.service
	sudo systemctl daemon-reload

	logf "%binfo:%b removing %b/etc/nix%b %b/etc/profile.d/nix.sh%b %b/etc/tmpfiles.d/nix-daemon.conf%b \
%b/nix%b %b~root/.nix-channels%b %b~root/.nix-profile%b %b~root/.cache/nix%b \n" \
"$BLUE" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET" \
"$MAGENTA" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET"
	sudo -rf /etc/nix /etc/profile.d/nix.sh /etc/tmpfiles.d/nix-daemon.conf /nix ~root/.nix-channels ~root/.nix-profile ~root/.cach/nix

	logf "%binfo:%b removing nixbld users...%b\n" "$BLUE" "$RESET"
	if
		for user in $(seq 1 32); do
			sudo userdel nixbld"$user"
		done
	then
		logf "%b✅ success.%b\n" "$GREEN" "$RESET"
	else
		logf "%b❌ failure.%b\n" "$RED" "$RESET"
		logf "%berror:%b failed to uninstall Nix.\n" "$RED" "$RESET"
		exit 1
	fi

	logf "%binfo:%b removing nixbld group...%b\n" "$BLUE" "$RESET"
	if sudo groupdel nixbld; then
		logf "%b✅ success.%b\n" "$GREEN" "$RESET"
	else
		logf "%b❌ failure.%b\n" "$RED" "$RESET"
		logf "%berror:%b failed to uninstall Nix.\n" "$RED" "$RESET"
		exit 1
	fi

	nix_files="/etc/bash.bashrc /etc/bashrc /etc/profile /etc/zsh/zshrc /etc/zshrc"

	for file in $nix_files; do
		if [ -f "$file" ] && grep -iq 'Nix' "$file"; then
			tmp_file="$(mktemp)"
			sed '/^# Nix$/,/^# End Nix$/d' "$file" >"$tmp_file"
			if ! cmp -s "$file" "$tmp_file"; then
				logf "%binfo:%b removing Nix entries from %b%s%b\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$file" "$RESET"
				cp "$file" "$file.bak"
				cp "$tmp_file" "$file"
				logf "%binfo:%b removed:\n"
				diff -u "$file.bak" "$file"
			fi
			rm -f "$tmp_file"
		fi
	done
	logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
	exit 0
}

if check_for_nix no_exit; then
	logf "%binfo:%b Nix detected.\n" "$BLUE" "$RESET"

	if [ -f /nix/nix-installer ]; then
		if /nix/nix-installer uninstall; then
			logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
			exit 0
		else
			logf "%berror:%b failed to uninstall Nix.\n" "$RED" "$RESET"
			exit 1
		fi
	fi

	logf "Do you wish to continue uninstalling Nix? Y/n\n"
	read -r continue
	if ! [ "$continue" = "Y" ]; then
		logf "Exiting...\n"
		exit 0
	fi

	if command -v systemctl >/dev/null 2>&1 && systemctl status nix-daemon.service >/dev/null 2>&1; then
		nix_multi_user_uninstall
	else
		logf "%binfo:%b removing %b/nix%b %b$HOME/.nix-channels%b %b$HOME/.nix-defexpr%b %b$HOME/.nix-profile%b\n" \
			"$BLUE" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET" "$MAGENTA" "$RESET"
		if sudo -rf /nix ~/.nix-channels ~/.nix-defexpr ~/.nix-profile; then
			logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
			if [ -f "$HOME/.profile" ] && grep -iq "nix" "$HOME/.profile"; then
				logf "%binfo: %b you may want remove references to Nix in %b%s%b" \
					"$BLUE" "$RESET" "$MAGENTA" "$HOME/.profile" "$RESET"
			fi
			exit 0
		else
			logf "%berror:%b failed to uninstall Nix.\n" "$RED" "$RESET"
			exit 1
		fi
	fi
else
	logf "%binfo:%b Nix not detected. Exiting...\n"
fi
