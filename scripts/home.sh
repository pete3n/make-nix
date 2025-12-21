#!/usr/bin/env sh
set -eu

# defaults
IS_FINAL_GOAL=0
mode=""  # "build" or "activate"

# parse flags
while [ $# -gt 0 ]; do
  case "$1" in
    -F)
      [ $# -ge 2 ] || { printf '%s: -F requires an argument\n' "${0##*/}" >&2; exit 2; }
      case "$2" in 0|1) IS_FINAL_GOAL=$2 ;; *) printf '%s: invalid -F value: %s\n' "${0##*/}" "$2" >&2; exit 2 ;; esac
      shift 2
      ;;
    -F[01])
      IS_FINAL_GOAL=${1#-F}
      shift
      ;;
    --build)
      [ -z "$mode" ] || { printf '%s: duplicate mode (--build/--activate)\n' "${0##*/}" >&2; exit 2; }
      mode="build"; shift
      ;;
    --activate)
      [ -z "$mode" ] || { printf '%s: duplicate mode (--build/--activate)\n' "${0##*/}" >&2; exit 2; }
      mode="activate"; shift
      ;;
    --) shift; break ;;
    -*) printf '%s: invalid option: %s\n' "${0##*/}" "$1" >&2; exit 2 ;;
    *)  break ;;
  esac
done

# no stray positional args allowed (optional; keep if you expect none)
[ "$#" -eq 0 ] || { printf '%s: unexpected argument: %s\n' "${0##*/}" "$1" >&2; exit 2; }

# ensure a mode was chosen
if [ -z "$mode" ]; then
  # if common.sh isn't sourced yet, use printf instead of logf
  printf '%s: error: no mode specified; use --build or --activate\n' "${0##*/}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

cleanup_on_exit() {
  status=$?
  if [ "$status" -ne 0 ] && [ "${IS_FINAL_GOAL:-0}" -eq 1 ]; then
    cleanup "$status" ERROR
  fi
  exit "$status"
}

trap 'cleanup_on_exit' 0

trap '
  [ "${IS_FINAL_GOAL:-0}" -eq 1 ] && cleanup 130 SIGNAL
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

if [ -z "$mode" ]; then
	logf "\n%berror:%b No mode was passed. Use --build or --activate.\n" "$RED" "$RESET"
	exit 1
fi

backup_prefix="backup-before-nix-hm"
base_build_cmd="NIX_CONFIG='extra-experimental-features = nix-command flakes' command nix run nixpkgs#home-manager -- build -b ${backup_prefix} --flake .#${user}@${host}"
base_build_print_cmd="NIX_CONFIG='extra-experimental-features = nix-command flakes' command nix run nixpkgs#home-manager -- build -b ${backup_prefix} --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"
base_activate_cmd="NIX_CONFIG='extra-experimental-features = nix-command flakes' command nix run nixpkgs#home-manager -- switch -b ${backup_prefix} --flake .#${user}@${host}"
base_activate_print_cmd="NIX_CONFIG='extra-experimental-features = nix-command flakes' command nix run nixpkgs#home-manager -- switch -b ${backup_prefix} --flake .#${CYAN}${user}${RESET}@${CYAN}${host}${RESET}"

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
	if ! [ "$rc" -eq 0 ]; then
		logf "\n%berror:%b home configuraiton build failed. Halting make-nix.\n" "$RED" "$RESET"
		sh "$SCRIPT_DIR/check_dirty_warn.sh"
		exit "$rc"
	else
		return 0
	fi
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
	if ! [ "$rc" -eq 0 ]; then
		logf "\n%berror:%b home configuraiton activation failed. Halting make-nix.\n" "$RED" "$RESET"
		exit "$rc"
	else
		return 0
	fi
}

if [ "$mode" = "build" ]; then
	if build "$base_build_cmd" "$base_build_print_cmd" "$dry_switch" "$dry_print_switch"; then
		logf "%b✅ success:%b home build complete.\n" "$GREEN" "$RESET"
	fi
elif [ "$mode" = "activate" ]; then
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
