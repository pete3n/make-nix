#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

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

if command -v nix >/dev/null 2>&1; then
	logf "\n%binfo:%b Nix found in PATH; skipping Nix installation...\n" "$BLUE" "$RESET"
	logf "If you want to re-install, please follow these instructions to uninstall first: \n"
	logf "%bhttps://nix.dev/manual/nix/latest/installation/uninstall.html%b\n" "$BLUE" "$RESET"
else
	if [ -f "$MAKE_NIX_INSTALLER" ]; then
		sh "$MAKE_NIX_INSTALLER" "$install_flags"
	else
		logf "\n%berror:%b Could not execute 'nix_installer.sh'.\n" "$RED" "$RESET"
		exit 1
	fi
fi

"$SCRIPT_DIR/enable_flakes.sh"

if is_truthy "${USE_CACHE:-}" && ! is_truth "${NIX_DARWIN:-}"; then
	"$SCRIPT_DIR"/set_cache_config.sh
fi

if is_truthy "${NIX_DARWIN:-}"; then
	if [ "${UNAME_S:-}" = "Darwin" ]; then
		logf "\n%b>>> Installing nix-darwin...%b\n" "$BLUE" "$RESET"
		check_for_nix exit

		# List of files in /etc to back up
		clobber_list="nix/nix.conf zshenv bashrc"
		logf "\n%binfo:%b backing up existing /etc files before Nix-Darwin install...\n"
		for file in $clobber_list; do
			if [ -e "/etc/$file" ]; then
				logf "\n%info:%b renaming %b%s%b to %b%s%b.before_darwin\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$file" "$RESET" "$MAGENTA" "$file" "$RESET"
				sudo mv "/etc/$file" "/etc/${file}.before_darwin"
			fi
		done

		"$SCRIPT_DIR"/write_make_opts.sh
		sudo nix run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake .
		logf "\n%berror:%b Nix-Darwin installation failed. Restoring original files...\n" "$RED" "$RESET"
		for file in $clobber_list; do
			if [ -e "/etc/${file}.before_darwin" ]; then
				logf "\n%info:%b renaming %b%s%b.before_darwin to %b%s%b\n" "$BLUE" "$RESET" \
					"$MAGENTA" "$file" "$RESET" "$MAGENTA" "$file" "$RESET"
				sudo mv "/etc/${file}.before_darwin" "/etc/$file"
			fi
		done
		exit 1
	else
		logf "\n%binfo:%b Skipping nix-darwin install: macOS not detected.\n" "$BLUE" "$RESET"
		exit 0
	fi
fi
