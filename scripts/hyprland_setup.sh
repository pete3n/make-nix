#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"
#
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

# Check for GDM
if ! command -v gdm3 >/dev/null 2>&1 && ! systemctl status gdm3.service >/dev/null 2>&1; then
	printf "\nGDM3 not detected. Exiting.\n"
	exit 0
fi

# Install session entry
HYPR_DESKTOP_ENTRY="/usr/share/wayland-sessions/hyprland.desktop"

if [ ! -f "$HYPR_DESKTOP_ENTRY" ]; then
	printf "\nCreating Hyprland desktop entry for GDM3...\n"
	sudo tee "$HYPR_DESKTOP_ENTRY" >/dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland Compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
EOF
else
	printf "\nHyprland desktop entry already exists.\n"
fi

# Optional: set Hyprland as default session for current user
DEFAULT_SESSION_DIR="$HOME/.dmrc"
if [ ! -f "$DEFAULT_SESSION_DIR" ]; then
	printf "\nCreating %s with Hyprland session...\n" "$DEFAULT_SESSION_DIR"
	cat <<EOF > "$DEFAULT_SESSION_DIR"
[Desktop]
Session=Hyprland
EOF
else
	printf "\n%s already exists; not overwriting.\n" "$DEFAULT_SESSION_DIR"
fi

printf "\n✅ Hyprland setup complete.\n"
