#!/usr/bin/env sh
set -eu

IS_FINAL_GOAL=0

while getopts ':F:' opt; do
  case "$opt" in
    F)
      case "$OPTARG" in
        0|1) IS_FINAL_GOAL=$OPTARG ;;
        *) printf '%s: invalid -F value: %s (expected 0 or 1)\n' "${0##*/}" "$OPTARG" >&2; exit 2 ;;
      esac
      ;;
    :)
      printf '%s: option -%s requires an argument\n' "${0##*/}" "$OPTARG" >&2
      exit 2
      ;;
    \?)
      printf '%s: invalid option -- %s\n' "${0##*/}" "$OPTARG" >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap '
  [ "${IS_FINAL_GOAL:-0}" -eq 1 ] && cleanup "$?" EXIT
' EXIT

trap '
  cleanup 130 SIGNAL
  exit 130
' INT TERM QUIT

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

base_build_cmd="nix run nixpkgs#home-manager -- build -b beckup-before-nix-hm --flake .#${user}@${host}"
base_build_print_cmd="nix run nixpkgs#home-manager -- build -b backup-before-nix-hm --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"
base_activate_cmd="nix run nixpkgs#home-manager -- switch -b backup-before-nix-hm --flake .#${user}@${host}"
base_activate_print_cmd="nix run nixpkgs#home-manager -- switch -b backup-before-nix-hm --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"

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

	logf "\n%b>>> Building Nix Home-manager configuration for:%b\n" "$BLUE" "$RESET"
	logf "%b%s%b on %b%s%b host %b%s%b\n" "$CYAN" "$user" "$RESET" "$CYAN" "$TGT_SYSTEM" "$RESET" \
		"$CYAN" "$host" "$RESET"
	logf "\n%bBuild command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if ! has_nix && (source_nix && has_nix); then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi

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

	logf "\n%b>>> Activating Nix Home-manager configuration for:\n"
	logf "%b%s%b on %b%s%b host %b%s%b %b%s%b\n" "$CYAN" "$user" "$RESET" \
		"$CYAN" "$TGT_SYSTEM" "$RESET" "$CYAN" "$host" "$RESET"
	logf "\n%bActivation command:%b %b\n\n" "$BLUE" "$RESET" "$print_cmd"

	if ! has_nix && (source_nix && has_nix); then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi

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
		if [ "${HYPRLAND_SETUP:-}" = true ]; then
			sh "$SCRIPT_DIR/hyprland_setup.sh"
		fi
	fi
else
	logf "\n%berror:%b Neither --build nor --activate was called for.\n" "$RED" "$RESET"
fi
