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
	logf "Are you sure you want to continue with uninstalling Nix-Darwin Y/n?\n"
	read -r continue
	if ! [ "${continue}" = "Y" ]; then
		logf "Exiting..."
		exit 0
	fi
	if ! sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller; then
		if ! sudo darwin-uninstaller; then
			logf "%berror:%b failed to uninstall Nix-Darwin.\n"
		else
			logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
		fi
	else
		logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
	fi
fi

if has_nix_darwin; then
	logf "%binfo:%b Nix-darwin detected.\n" "$BLUE" "$RESET"
	if ! sudo darwin-uninstaller; then
		if ! sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller; then
			logf "%berror:%b failed to uninstall Nix-Darwin.\n"
		else
			logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
		fi
	else
		logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
	fi
fi

if [ -f /nix/nix-installer ]; then
	if sh /nix/nix-installer uninstall; then
		logf "%b✅ success:%b uninstall complete.\n" "$GREEN" "$RESET"
	else
		logf "%berror:%b failed to uninstall Nix.\n" "$RED" "$RESET"
	fi
else
	logf "%binfo:%b could not find Nix uninstaller.\n"
	exit 1
fi
