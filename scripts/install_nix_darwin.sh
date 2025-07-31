#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

clobber_list="nix/nix.conf zshenv zshrc bashrc"
restored=false
restoration_list=""

restore_clobbered_files() {
  if [ "$restored" = false ] && [ -n "$restoration_list" ]; then
    logf "\n%binfo:%b restoring original files after failed install...\n" "$BLUE" "$RESET"
    for file in $restoration_list; do
      if [ -e "/etc/${file}.before_darwin" ]; then
        logf "  ↩️  restoring /etc/%s\n" "$file"
        sudo mv "/etc/${file}.before_darwin" "/etc/$file"
      fi
    done
    restored=true
  fi
}

trap 'restore_clobbered_files' EXIT INT TERM QUIT

logf "\n%binfo:%b backing up files before Nix-Darwin install...\n" "$BLUE" "$RESET"
for file in $clobber_list; do
  if [ -e "/etc/$file" ]; then
    logf "%b🗂  moving%b %b/etc/%s%b → %b/etc/%s.before_darwin%b\n" "$BLUE" "$RESET" \
			"$MAGENTA" "$file" "$RESET" "$MAGENTA" "$file" "$RESET"
    sudo mv "/etc/$file" "/etc/${file}.before_darwin"
    restoration_list="$restoration_list $file"
  fi
done

"$SCRIPT_DIR/write_make_opts.sh"

nix_conf_backup="/etc/nix/nix.conf.before_darwin"
if [ -f "$nix_conf_backup" ]; then
  # Extract line and strip leading/trailing whitespace
  subs_line=$(grep '^trusted-substituters[[:space:]]*=' "$nix_conf_backup" || true)
  if [ -n "$subs_line" ]; then
    subs_values=$(printf "%s\n" "$subs_line" | cut -d'=' -f2- | sed 's/^ *//' | tr -s ' ')
    substituters="$subs_values"
  fi
fi

if [ "${substituters:-x}" ]; then
	substituters=""
fi

if sudo nix run --option experimental-features "nix-command flakes" --option trusted-substituters \""$substituters"\" nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .; then
  logf "\n%b✓%b Nix-Darwin install succeeded. Cleaning up backups...\n" "$GREEN" "$RESET"
  for file in $restoration_list; do
    sudo rm -f "/etc/${file}.before_darwin"
  done
  # Prevent restoration on trap
  restoration_list=""
else
  logf "\n%b❌%b Nix-Darwin install failed. Files will be restored.\n" "$RED" "$RESET"
  exit 1
fi
