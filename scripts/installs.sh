#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

MAKE_GOALS="${1:-install}" # default to "install" if nothing is passed
CURRENT_TARGET="${CURRENT_TARGET:-install}"

# install can be one of multiple targets, if it is the last target, then we
# want to cleanup the environment artifacts, otherwise we need to preserve them.
others=$(
	printf '%s\n' "$MAKE_GOALS" |
		tr ' ' '\n' |
		grep -v -x "$CURRENT_TARGET" |
		sed '/^$/d'
)
IS_FINAL_GOAL=false
[ -z "$others" ] && IS_FINAL_GOAL=true
export IS_FINAL_GOAL

trap '
  [ "${IS_FINAL_GOAL:-0}" -eq 1 ] && cleanup "$?" EXIT
' EXIT
trap 'cleanup 130 SIGNAL' INT TERM QUIT # one generic non-zero code for signals

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

if [ "${UNAME_S:-}" != "Linux" ] && [ "${UNAME_S:-}" != "Darwin" ]; then
	logf "%binfo%b: unsupported OS: %s\n" "$BLUE" "$RESET" "${UNAME_S:-}"
	exit 1
fi

if has_nixos; then
	logf "%binfo:%b NixOS is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

if has_nix_darwin; then
	logf "%binfo:%b Nix-Darwin is installed. Installation aborted...\n" "$BLUE" "$RESET"
	exit 0
fi

sh "$SCRIPT_DIR/check_deps.sh" "$MAKE_GOALS"

# Only the determinate installer works with SELinux
if [ -z "${DETERMINATE:-}" ]; then
	if command -v getenforce >/dev/null 2>&1; then
		case "$(getenforce 2>/dev/null)" in
		Enforcing | Permissive)
			logf "\n%binfo:%b SELinux detected (%s). Using Determinate Systems installer.\n" \
				"${BLUE:-}" "${RESET:-}" "$(getenforce)"
			DETERMINATE=true
			;;
		esac
	elif [ -f /sys/fs/selinux/enforce ] && [ "$(cat /sys/fs/selinux/enforce 2>/dev/null)" = "1" ]; then
		logf "\n%binfo:%b SELinux detected (sysfs).  Using Determinate Systems installer.\n" \
			"${BLUE:-}" "${RESET:-}"
		DETERMINATE=true
	fi
fi

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

if has_nix; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	logf "If you want to re-install, please run 'make uninstall' first.\n"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"

		# Make nix available immediately in the current shell
		source_nix

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
		printf "%s\n" "$features" >>"$nix_conf"
	fi
else
	logf "\n%b>>> Creating nix.conf with experimental features enabled...%b\n" "$BLUE" "$RESET"
	mkdir -p "$(dirname "$nix_conf")"
	printf "%s\n" "$features" >"$nix_conf"
fi

# Set user-defined binary cache URLs and Nix trusted public keys from make.env.
# This is set before Nix-Darwin install so it can take advantage of cacheing.
if is_truthy "${USE_KEYS:-}" || is_truthy "${USE_CACHE:-}"; then
	sh "$SCRIPT_DIR/set_subs_keys.sh"
fi

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

		if ! has_nix && (source_nix && has_nix); then
			logf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
			exit 1
		fi

		sh "$SCRIPT_DIR/install_nix_darwin.sh"
	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi

if has_goal install && has_goal home && has_tag hyprland; then
	printf "HYPRLAND_SETUP=true\n" >>"$MAKE_NIX_ENV"
fi

other_targets=$(printf "%s\n" "$MAKE_GOALS" | tr ' ' '\n' | grep -v '^install$')
if [ -z "$other_targets" ]; then
	cleanup 0 EXIT
fi
