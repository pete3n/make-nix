#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

if ! has_nix; then
	source_nix
	if ! has_nix; then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi
fi

if [ -z "${TGT_SYSTEM:-}" ]; then
	logf "\n%berror:%b Could not determine target system platform.\n" "$RED" "$RESET"
	exit 1
fi

if [ -z "${IS_LINUX:-}" ]; then
	logf "\n%berror:%b Could not determine if target system is Linux or Darwin.\n" "$RED" "$RESET"
	exit 1
fi

user="${TGT_USER:? error: user must be set.}"
host="${TGT_HOST:? error: host must be set.}"
: "${USE_SCRIPT:=false}"

mode="${1:-}"
if [ -z "$mode" ]; then
	logf "\n%berror:%b No mode was passed. Use --build or --activate.\n" "$RED" "$RESET"
	exit 1
fi

base_darwin_build_cmd="nix build .#darwinConfigurations.${host}.system"
base_darwin_build_print_cmd="nix build .#darwinConfigurations.${CYAN}${host}${RESET}.system"
base_darwin_activate_cmd="sudo ./result/sw/bin/darwin-rebuild switch --flake .#${host}"
base_darwin_activate_print_cmd="sudo ./result/sw/bin/darwin-rebuild switch --flake .#${CYAN}${host}${RESET}"

base_linux_build_cmd="nix build .#nixosConfigurations.${user}@${host}.config.system.build.toplevel"
base_linux_build_print_cmd="nix build .#nixosConfigurations.${CYAN}${user}@${host}${RESET}.config.system.build.toplevel"
base_linux_activate_cmd="sudo ./result/sw/bin/nixos-rebuild switch --flake .#${host}"
base_linux_activate_print_cmd="sudo ./result/sw/bin/nixos-rebuild switch --flake .#${CYAN}${host}${RESET}"

nix_cmd_switch="--extra-experimental-features nix-command"
flake_switch="--extra-experimental-features flakes"
dry_switch=""
if is_truthy "${DRY_RUN:-}"; then
	dry_switch="--dry-run"
fi
dry_print_switch="${BLUE}${dry_switch}${RESET}"

build() {
	base_cmd=$1
	print_cmd=$2
	switches=$3
	print_switches=$4
	build_cmd="${base_cmd} ${switches}"
	print_cmd="${print_cmd} ${print_switches}"
	rcfile="$(mktemp)"

	if ! has_nix && (source_nix && has_nix); then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi

	logf "\n%b>>> Building system configuration for:%b\n" "$BLUE" "$RESET"
	logf "%b%s%b host %b%s%b\n" "$CYAN" "$TGT_SYSTEM" "$RESET" \
		"$CYAN" "$host" "$RESET"
	logf "\n%bBuild command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if is_truthy "${USE_SCRIPT:-}"; then
		script -a -q -c "$build_cmd; printf '%s\n' \$? > \"$rcfile\"" "$MAKE_NIX_LOG"
	else
		# Wrap in subshell to capture exit code to a file
		(
			eval "$build_cmd"
			printf "%s\n" "$?" >"$rcfile"
		) 2>&1 | tee "$MAKE_NIX_LOG"
	fi

	rc=$(cat "$rcfile")
	rm -f "$rcfile"
	return "$rc"
}

activate() {
	activate_cmd=$1
	print_cmd=$2
	rcfile="$(mktemp)"

	if ! has_nix && (source_nix && has_nix); then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi

	if [ "$UNAME_S" = "Linux" ] && ! has_nixos; then
		logf "\n%berror:%b cannot activate a NixOS system configuration on Linux without %bnixos-rebuild%b.\n" \
			"$RED" "$RESET" "$RED" "$RESET"
	fi

	if [ "$UNAME_S" = "Darwin" ] && ! has_nix_darwin; then
		logf "\n%berror:%b cannot activate a Nix-Darwin system configuration on Darwin without darwin-rebuild.\n" \
			"$RED" "$RESET" "$RED" "$RESET"
	fi

	logf "\n%b>>> Activating%b system configuration for %b%s%b host %b%s%b\n" \
		"$BLUE" "$RESET" "$CYAN" "$TGT_SYSTEM" "$RESET" "$CYAN" "$host" "$RESET"
	logf "\n%bActivate command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if is_truthy "${USE_SCRIPT:-}"; then
		script -a -q -c "$activate_cmd; printf '%s\n' \$? > \"$rcfile\"" "$MAKE_NIX_LOG"
	else
		# Wrap in subshell to capture exit code to a file
		(
			eval "$activate_cmd"
			printf "%s\n" "$?" >"$rcfile"
		) 2>&1 | tee "$MAKE_NIX_LOG"
	fi

	rc=$(cat "$rcfile")
	rm -f "$rcfile"
	return "$rc"
}

if is_truthy "${IS_LINUX:-}"; then
	if [ "$mode" = "--build" ]; then
		build "$base_linux_build_cmd" "$base_linux_build_print_cmd" \
			"${dry_switch} ${nix_cmd_switch} ${flake_switch}" \
			"${dry_print_switch} ${nix_cmd_switch} ${flake_switch}"
	elif [ "$mode" = "--activate" ]; then
		if [ "$dry_switch" = "--dry-run" ]; then
			logf "\n%bDRY_RUN%b %btrue%b: skipping system activation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
			exit 0
		fi
		activate "$base_linux_activate_cmd" "$base_linux_activate_print_cmd"
	else
		logf "\n%berror:%b Neither --build nor --activate was called for.\n" "$RED" "$RESET"
	fi
else
	if [ "$mode" = "--build" ]; then
		build "$base_darwin_build_cmd" "$base_darwin_build_print_cmd" \
			"${dry_switch} ${nix_cmd_switch} ${flake_switch}" \
			"${dry_print_switch} ${nix_cmd_switch} ${flake_switch}"
	elif [ "$mode" = "--activate" ]; then
		if [ "$dry_switch" = "--dry-run" ]; then
			logf "\n%bDRY_RUN%b %btrue%b: skipping system activation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
			exit 0
		fi
		activate "$base_darwin_activate_cmd" "$base_darwin_activate_print_cmd"
	else
		logf "\n%berror:%b Neither --build nor --activate was called for.\n" "$RED" "$RESET"
	fi
fi
