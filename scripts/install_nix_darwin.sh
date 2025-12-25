#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

clobber_list="zshenv zshrc bashrc"
restored=false
restoration_list=""

_backup_files() {
	for file in $clobber_list; do
		if [ -e "/etc/${file}" ]; then
			logf "%binfo:%b backing up /etc/%s\n" "$C_CFG" "$C_RST" "$file"
			sudo mv "/etc/$file" "/etc/${file}.before_darwin"
		fi
	done
	if [ -f /etc/nix/nix.conf ]; then
		sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before_darwin
	fi
}

_restore_clobbered_files() {
	if [ "$restored" = false ] && [ -n "$restoration_list" ]; then
		logf "\n%binfo:%b restoring original files after failed install...\n" "$C_CFG" "$C_RST"
		for file in $restoration_list; do
			if [ -e "/etc/${file}.before_darwin" ]; then
				logf "  ↩️  restoring /etc/%s\n" "$file"
				if sudo cp "/etc/${file}.before_darwin" "/etc/$file"; then
					sudo rm -f "/etc/${file}.before_darwin"
				fi
			fi
		done
		restored=true
	fi
}

trap '_restore_clobbered_files' EXIT INT TERM QUIT
trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

_ensure_nix_daemon() {
	if ! [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
		logf "\n%berror:%b nix-daemon binary missing in default profile\n" "$C_ERR" "$C_RST"
		exit 1
	fi

	sudo launchctl enable system/org.nixos.nix-daemon || true
	sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true
	sudo launchctl kickstart -k system/org.nixos.nix-daemon || true

	# Wait for the socket
	i=1
	while [ $i -lt 20 ] && ! [ -S /nix/var/nix/daemon-socket/socket ]; do
		i=$((i + 1))
		sleep 0.1
	done

	if ! [ -S /nix/var/nix/daemon-socket/socket ]; then
		logf "\n%berror:%b nix-daemon socket missing after bootstrap/kickstart\n" "$C_ERR" "$C_RST"
		sudo launchctl print system/org.nixos.nix-daemon | sed -n '1,120p' >&2 || true
		exit 1
	fi
}

logf "\n%binfo:%b backing up files before Nix-Darwin install...\n" "$C_CFG" "$C_RST"
for file in $clobber_list; do
	if [ -e "/etc/$file" ]; then
		logf "%b🗂  moving%b %b/etc/%s%b → %b/etc/%s.before_darwin%b\n" "$C_CFG" "$C_RST" \
			"$MAGENTA" "$file" "$C_RST" "$MAGENTA" "$file" "$C_RST"
		sudo mv "/etc/$file" "/etc/${file}.before_darwin"
		restoration_list="$restoration_list $file"
	fi
done

"$SCRIPT_DIR/attrs.sh --write"

# Re-source env because attrs updates env
# shellcheck disable=SC1090
. "$MAKE_NIX_ENV"

nix_conf_backup="/etc/nix/nix.conf.before_darwin"
substituters=""

if [ -f "$nix_conf_backup" ]; then
	subs_line=$(grep '^trusted-substituters[[:space:]]*=' "$nix_conf_backup" || true)
	if [ -n "$subs_line" ]; then
		subs_values=$(printf "%s\n" "$subs_line" | cut -d'=' -f2- | sed 's/^ *//' | tr -s ' ')
		substituters="$subs_values $substituters"
	fi
fi

_ensure_nix_daemon

if has_cmd "darwin-rebuild"; then
	logf "\n%binfo:%b Nix-Darwin already appears to be installed. Skipping installation...\n" "$C_CFG" "$C_RST"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
	exit 0
fi

logf "\n%binfo:%b building Nix-Darwin with command:\n" "$C_CFG" "$C_RST"
logf "nix build --option experimental-features \"nix-command flakes\" .#darwinConfigurations.%b%s%b@%b%s%b.system\n" \
	"$CYAN" "$TGT_USER" "$C_RST" "$CYAN" "$TGT_HOST" "$C_RST"
if nix build --option experimental-features "nix-command flakes" .#darwinConfigurations."${TGT_USER}@${TGT_HOST}".system; then
	logf "\n%b✓ Nix-Darwin build success.%b\n" "$C_OK" "$C_RST"
else
	logf "\n%b❌%b Nix-Darwin build failed. Files will be restored.\n" "$C_ERR" "$C_RST"
	exit 1
fi

_backup_files

logf "\n%binfo:%b activating Nix-Darwin with command:\n" "$C_CFG" "$C_RST"
logf "sudo ./result/activate\n"
if sudo ./result/activate; then
	logf "\n%b✓ Nix-Darwin activation success.%b\n" "$C_OK" "$C_RST"
	# Prevent restoration on trap
	restoration_list=""
else
	logf "\n%b❌%b Nix-Darwin activation failed. Files will be restored.\n" "$C_ERR" "$C_RST"
	exit 1
fi
