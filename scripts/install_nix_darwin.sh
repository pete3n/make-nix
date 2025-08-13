#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

clobber_list="zshenv zshrc bashrc"
restored=false
restoration_list=""

restore_clobbered_files() {
  if [ "$restored" = false ] && [ -n "$restoration_list" ]; then
    logf "\n%binfo:%b restoring original files after failed install...\n" "$BLUE" "$RESET"
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

trap 'restore_clobbered_files' EXIT INT TERM QUIT
trap 'cleanup $? EXIT' EXIT
trap 'cleanup 130 SIGNAL' INT TERM QUIT   # one generic non-zero code for signals

logf "\n%binfo:%b backing up files before Nix-Darwin install...\n" "$BLUE" "$RESET"
for file in $clobber_list; do
  if [ -e "/etc/$file" ]; then
    logf "%b🗂  moving%b %b/etc/%s%b → %b/etc/%s.before_darwin%b\n" "$BLUE" "$RESET" \
			"$MAGENTA" "$file" "$RESET" "$MAGENTA" "$file" "$RESET"
    sudo mv "/etc/$file" "/etc/${file}.before_darwin"
    restoration_list="$restoration_list $file"
  fi
done

"$SCRIPT_DIR/write_nix_attrs.sh"

# Re-source env because write_nix_attrs could pupulate user, host, system etc.
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

# --- run as a regular user, not root ---
if [ "$(id -u)" -eq 0 ]; then
  logf "\n%berror:%b do not run this installer as root.\n" "$RED" "$RESET"
  exit 1
fi

# Force client/daemon mode and clear any leaked local-mode env.
unset NIX_REMOTE NIX_STORE_DIR NIX_STATE_DIR NIX_LOG_DIR NIX_CONF_DIR NIX_DATA_DIR || true
export NIX_REMOTE=daemon

if ! /bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
  logf "\n%berror:%b nix-daemon is not loaded. Try:\n  sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist\n" \
		"$RED" "$RESET"
  exit 1
fi

if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
  logf "\n%berror:%b nix-daemon socket missing at /nix/var/nix/daemon-socket/socket\n" "$RED" "$RESET"
  exit 1
fi

logf "\n%binfo:%b installing Nix-Darwin with command:\n" "$BLUE" "$RESET"
logf "nix run --option experimental-features \"nix-command flakes\" --option trusted-substituters \"$substituters\" nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .#%s\n" "$TGT_HOST" 
if nix run --option experimental-features "nix-command flakes" --option trusted-substituters "$substituters" nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .#"${TGT_HOST}"; then
  logf "\n%b✓ Nix-Darwin install succeeded.%b\n" "$GREEN" "$RESET"
  # Prevent restoration on trap
  restoration_list=""
else
  logf "\n%b❌%b Nix-Darwin install failed. Files will be restored.\n" "$RED" "$RESET"
  exit 1
fi
