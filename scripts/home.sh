#!/usr/bin/env sh
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"
trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

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

base_build_cmd="nix run nixpkgs#home-manager -- build -b backup --flake .#${user}@${host}"
base_build_print_cmd="nix run nixpkgs#home-manager -- build -b backup --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"
base_activate_cmd="nix run nixpkgs#home-manager -- switch -b backup --flake .#${user}@${host}"
base_activate_print_cmd="nix run nixpkgs#home-manager -- switch -b backup --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"

dry_switch=""
if is_truthy "${DRY_RUN:-}"; then
	dry_switch="--dry-run"
fi
dry_print_switch="${BLUE}${dry_switch}${RESET}"

check_for_nix exit

build() {
	base_cmd=$1
	print_cmd=$2
	switches=$3
	print_switches=$4
	build_cmd="${base_cmd} ${switches}"
	print_cmd="${print_cmd} ${print_switches}"

	logf "\n%b>>> Building Nix Home-manager configuration for:%b\n" "$BLUE" "$RESET"
	logf "%b%s%b on %b%s%b host %b%s%b\n" "$CYAN" "$user" "$RESET" "$CYAN" "$TGT_SYSTEM" "$RESET" \
		"$CYAN" "$host" "$RESET"
	logf "\n%bBuild command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if is_truthy "${USE_SCRIPT:-}"; then
		script -a -q -c "$build_cmd" "$MAKE_NIX_LOG"
		return $?
	else
		eval "$build_cmd" | tee "$MAKE_NIX_LOG"
		return $?
	fi
}

activate() {
	activate_cmd=$1
	print_cmd=$2

	logf "\n%b>>> Activating Nix Home-manager configuration for:\n"
	logf "%b%s%b on %b%s%b host %b%s%b %b%s%b\n" "$CYAN" "$user" "$RESET" \
		"$CYAN" "$TGT_SYSTEM" "$RESET" "$CYAN" "$host" "$RESET"
	logf "\n%bActivation command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if is_truthy "${USE_SCRIPT:-}"; then
		script -a -q -c "$activate_cmd" "$MAKE_NIX_LOG"
		return $?
	else
		eval "$activate_cmd" | tee "$MAKE_NIX_LOG"
		return $?
	fi
}

if [ "$mode" = "--build" ]; then
	if build "$base_build_cmd" "$base_build_print_cmd" "$dry_switch" "$dry_print_switch"; then
		logf "%b✅ success:%b home build complete.\n" "$GREEN" "$RESET"
	fi
elif [ "$mode" = "--activate" ]; then
	if [ "$dry_switch" = "--dry-run" ]; then
		logf "\n%bDRY_RUN%b %btrue%b: skipping home activation...\n" "$BLUE" "$RESET" "$GREEN" "$RESET"
		exit 0
	fi
	if activate "$base_activate_cmd" "$base_activate_print_cmd"; then
		logf "%b✅ success:%b home activation complete.\n" "$GREEN" "$RESET"
	fi
else
	logf "\n%berror:%b Neither --build nor --activate was called for.\n" "$RED" "$RESET"
fi
