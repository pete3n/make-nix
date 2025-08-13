#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"
#

trap 'cleanup $? EXIT' EXIT
trap 'cleanup 130 SIGNAL' INT TERM QUIT   # one generic non-zero code for signals

logf "\n%b>>> Running Hyprland setup for display manager...%b\n" "$BLUE" "$RESET"
# Ensure GDM isn’t forcing Xorg (WaylandEnable=false)
if [ -f /etc/gdm3/custom.conf ]; then
  if grep -q '^WaylandEnable=false' /etc/gdm3/custom.conf; then
    logf "\n%binfo:%b enabling Wayland in /etc/gdm3/custom.conf\n" "${BLUE:-}" "${RESET:-}"
    sudo sed -i 's/^WaylandEnable=false/# WaylandEnable=false/' /etc/gdm3/custom.conf
  fi
else
  logf "\n%binfo:%b /etc/gdm3/custom.conf not found; skipping Wayland check.\n" "${BLUE:-}" "${RESET:-}"
fi

WRAPPER=/usr/local/bin/hyprland-dm-session
logf "%binfo:%b Writing wrapper: %b%s%b\n" "${BLUE:-}" "${RESET:-}" "${MAGENTA:-}" "$WRAPPER" "${RESET:-}"
sudo install -D -m 0755 /dev/stdin "$WRAPPER" <<'EOF'
#!/bin/sh
set -eu

# Make Nix tools visible for GDM sessions
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
PATH="$HOME/.nix-profile/bin:$PATH"; export PATH

# Wayland/session hints
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export MOZ_ENABLE_WAYLAND=1
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
# If NVIDIA is quirky:
# export WLR_NO_HARDWARE_CURSORS=1

# If a user bus already exists (GDM provides this), don’t spawn another
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/bus" ]; then
  exec Hyprland
else
  exec dbus-run-session Hyprland
fi
EOF

DESKTOP=/usr/share/wayland-sessions/hyprland.desktop
logf "%binfo:%b Writing desktop entry: %b%s%b\n" "${BLUE:-}" "${RESET:-}" "${MAGENTA:-}" "$DESKTOP" "${RESET:-}"
sudo install -D -m 0644 /dev/stdin "$DESKTOP" <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland Compositor
Exec=$WRAPPER
TryExec=$WRAPPER
Type=Application
DesktopNames=Hyprland
EOF

logf "\n%b✅ success:%b Hyprland session registered. Pick 'Hyprland' in GDM.\n" "${GREEN:-}" "${RESET:-}"
