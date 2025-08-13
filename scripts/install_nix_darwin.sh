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

ensure_nix_daemon() {
  # Ensure the daemon binary path exists
  if ! [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
    logf "\n%berror:%b nix-daemon binary missing in default profile\n" "$RED" "$RESET"
    exit 1
  fi

  # Enable & bootstrap the service in the system domain
  sudo launchctl enable system/org.nixos.nix-daemon || true
  sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true
  sudo launchctl kickstart -k system/org.nixos.nix-daemon || true

  # Wait for the socket
  i=1
  while [ $i -lt 20 ] && ! [ -S /nix/var/nix/daemon-socket/socket ]; do
    i=$((i+1)); sleep 0.1
  done
  if ! [ -S /nix/var/nix/daemon-socket/socket ]; then
    logf "\n%berror:%b nix-daemon socket missing after bootstrap/kickstart\n" "$RED" "$RESET"
    sudo launchctl print system/org.nixos.nix-daemon | sed -n '1,120p' >&2 || true
    exit 1
  fi

  # Force client→daemon mode (avoid env leakage)
  unset NIX_REMOTE || true
  export NIX_REMOTE=daemon
}

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

if ! /bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
	ensure_nix_daemon
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
