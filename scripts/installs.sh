#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

MAKE_GOALS="${1:-install}" # default to "install" if nothing is passed

check_integrity() {
	URL=$1
	EXPECTED_HASH=$2

	curl -Ls "$URL" >"$MAKE_NIX_INSTALLER"
	# shellcheck disable=SC2002
	ACTUAL_HASH=$(cat "$MAKE_NIX_INSTALLER" | shasum | cut -d ' ' -f 1)

	if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
		logf "\n%bIntegrity check failed!%b\n" "$YELLOW" "$RESET"
		logf "Expected: %b" "$EXPECTED_HASH\n"
		logf "Actual:   %b" "$RED$ACTUAL_HASH$RESET\n"
		logf "%bCheck%b the URL and HASH values in your make.env file.\n" "$BLUE" "$RESET"
		rm "$MAKE_NIX_INSTALLER"
		exit 1
	else
		logf "\n%b✅Integrity check passed.%b\n" "$GREEN" "$RESET"
		chmod +x "$MAKE_NIX_INSTALLER"
	fi
}

if has_nixos; then
	printf "%binfo:%b NixOS is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

if has_nix_darwin; then
	printf "%binfo:%b Nix-Darwin is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

if [ "${UNAME_S:-}" != "Linux" ] && [ "${UNAME_S:-}" != "Darwin" ]; then
	printf "%binfo%b: unsupported OS: %s\n" "$BLUE" "$RESET" "${UNAME_S:-}"
	exit 1
fi

sh "$SCRIPT_DIR/check_deps.sh" "$MAKE_GOALS"

# Integrity checks
if is_truthy "${DETERMINATE:-}"; then
	logf "\n%b>>> Verifying Determinate Systems installer integrity...%b\n" "$BLUE" "$RESET"
	check_integrity "$DETERMINATE_INSTALL_URL" "$DETERMINATE_INSTALL_HASH"
else
	logf "\n%b>>> Verifying Nix installer integrity...%b\n" "$BLUE" "$RESET"
	check_integrity "$NIX_INSTALL_URL" "$NIX_INSTALL_HASH"
fi

# Launch installers
logf "\n%b>>> Launching installer...%b\n" "$BLUE" "$RESET"

install_flags=""
if is_truthy "${DETERMINATE:-}"; then
	install_flags="$DETERMINATE_INSTALL_MODE"
else
	if is_truthy "${SINGLE_USER:-}"; then
		install_flags="--no-daemon"
	else
		install_flags="$NIX_INSTALL_MODE"
	fi
fi

if check_for_nix no_exit; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"
	else
		logf "\n%berror:%b Could not execute 'sh %b'.\n" "$RED" "$RESET" "$MAKE_NIX_INSTALLER"
		exit 1
	fi
fi

# Enabled flakes (Required before Nix-Darwin install)
nix_conf="$HOME/.config/nix/nix.conf"
features="experimental-features = nix-command flakes"

if [ -f "$nix_conf" ]; then
	if ! grep -qF "nix-command flakes" "$nix_conf"; then
		logf "\n%b>>> Enabling flakes...%b\n" "$BLUE" "$RESET"
		logf "\n%binfo:%b appending %s to %b%s%b\n" "$BLUE" "$RESET" "$features" \
			"$MAGENTA" "$nix_conf" "$RESET"
		printf "%s\n" "$features" >> "$nix_conf"
	fi
else
	logf "\n%b>>> Creating nix.conf with experimental features enabled...%b\n" "$BLUE" "$RESET"
	mkdir -p "$(dirname "$nix_conf")"
	printf "%s\n" "$features" > "$nix_conf"
fi

# Set user-defined binary cache URLs and Nix trusted public keys from make.env. 
# This is set before Nix-Darwin install so it can take advantage of cacheing.
sh "$SCRIPT_DIR/set_subs_keys.sh"

# Optional Homebrew install
if is_truthy "${USE_HOMEBREW:-}" && [ "${UNAME_S}" = "Darwin" ]; then
	logf "\n%b>>> Installing Homebrew...%b\n" "$BLUE" "$RESET"
	logf "\n%binfo:%bVerifying Homebrew installer integrity...\n" "$BLUE" "$RESET"
	# Overwrites previous mktmp installer
	check_integrity "$HOMEBREW_INSTALL_URL" "$HOMEBREW_INSTALL_HASH"
	if command -v bash >/dev/null 2>&1; then
		bash -c "$MAKE_NIX_INSTALLER"
	else
		logf "\n%berror:%b bash was not found. This is required for Homebrew installation.\n" "$RED" "$RESET"
		exit 1
	fi
fi

# Optional Nix-Darwin install
if is_truthy "${NIX_DARWIN:-}"; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		logf "\n%b>>> Installing nix-darwin...%b\n" "$BLUE" "$RESET"
		check_for_nix exit
		sh "$SCRIPT_DIR/install_nix_darwin.sh"
	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi

other_targets=$(printf "%s\n" "$MAKE_GOALS" | tr ' ' '\n' | grep -v '^install$')
if [ -z "$other_targets" ]; then
	sh "$SCRIPT_DIR/clean.sh"
fi
