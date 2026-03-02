#!/usr/bin/env sh

# Functions for building and switching NixOS or Nix-Darwin system configurations.

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: system.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

flake_root="$(cd "${script_dir}/.." && pwd)"
prog=""
mode=""
user=""
host=""
is_linux=""
dry_switch=""
darwin_install=""
spec=""

_set_switch_spec() {
	_switch_spec_in=${SWITCH_SPEC:-}

	# Normalize SPECS into one-per-line, trimmed, drop empties
	_specs_nl=$(
		printf '%s' "${SPECS:-}" |
		tr ',' '\n' |
		sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
	)

	if [ -z "$_specs_nl" ]; then
		logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "${C_INFO}" "${C_RST}"
		exit 0
	fi

	# Truthy => take first
	if is_truthy "$_switch_spec_in"; then
		_first_spec=$(printf '%s\n' "$_specs_nl" | sed -n '1p')
		spec="${_first_spec}"
		return 0
	fi

	if [ -z "$_switch_spec_in" ]; then
		logf "\n%binfo:%b No valid specialisation found. Skipping...\n" "${C_INFO}" "${C_RST}"
		exit 0
	fi

	# Trim BOOT_SPEC for comparison
	_switch_spec_in=$(printf '%s' "$_switch_spec_in" | xargs)

	# Validate membership
	if printf '%s\n' "$_specs_nl" | grep -Fx -- "$_switch_spec_in" >/dev/null 2>&1; then
		spec="${_switch_spec_in}"
		return 0
	fi

	# Not valid => discard with warning
	logf "\n%bwarn:%b BOOT_SPEC '%s' not in available SPECS (%s). Ignoring.\n" \
		"${C_WARN}" "${C_RST}" "$_switch_spec_in" "${SPECS:-}"
	spec=""
	return 1
}

# Build system (nixos)
_build_nixos() {
	_attrset="${user}@${host}"
	logf "\n%b>>> Building system configuration for:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: --dry-run%b - no result output will be created.\n" "${C_INFO}" "${C_RST}"
	fi
 
	set -- nix build -L --max-jobs auto --cores 0 
	if is_truthy "${NO_SUB:-}"; then
		set -- "$@" --option substitute false
	fi
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --out-link "result-${host}-nixos" \
		"path:${flake_root}#nixosConfigurations.\"${_attrset}\".config.system.build.toplevel"

	print_cmd -- NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nixos build success.%b\n" "${C_OK}" "${C_RST}"
		logf "\n%bResult in:\n%b %b%s/result-%s-nixos%b\n" \
    "${C_INFO}" "${C_RST}" "${C_PATH}" "${flake_root}" "${_attrset}" "${C_RST}"
		return 0
	else
		err 1 "Nixos build failed."
	fi
}

# Build system (nix-darwin)
_build_darwin() {
	_attrset="${user}@${host}"
	logf "\n%b>>> Building system configuration for:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: --dry-run%b - no result output will be created.\n" "${C_INFO}" "${C_RST}"
	fi
	
	set -- nix build --max-jobs auto --cores 0
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --out-link "result-${host}-darwin" \
		"${flake_root}#darwinConfigurations.\"${_attrset}\".system"

	print_cmd -- NIX_CONFIG='"extra-experimental-features = nix-command flakes"' "$@"

	if NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nix-Darwin build success.%b\n" "${C_OK}" "${C_RST}"
		logf "\n%bResult in:\n%b %b%s/result-%s-darwin%b\n" \
    "${C_INFO}" "${C_RST}" "${C_PATH}" "${flake_root}" "${_attrset}" "${C_RST}"
		return 0
	else
		err 1 "Nix-Darwin build failed."
	fi
}

# Switch system configuration (nixos)
_switch_nixos() {
	_attrset="${user}@${host}"
	_result_bin="./result-${host}-nixos/sw/bin/nixos-rebuild"
	_rebuild_bin=""

	if has_cmd "nixos-rebuild"; then
		_rebuild_bin="nixos-rebuild"
	fi

 	if [ -x "${_result_bin}" ]; then
		_rebuild_bin="${_result_bin}"
	fi

	if [ -z "${_rebuild_bin}" ]; then
		logf "\n%binfo:%b nixos-rebuild binary not found...\n" "${C_INFO}" "${C_RST}"
		_build_nixos
		if [ -x "${_result_bin}" ]; then
			_rebuild_bin="${_result_bin}"
		fi
	fi

	if [ -z "${_rebuild_bin}" ]; then
		err 1 "Could not locate nixos-rebuild binary."
	fi

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: --dry-run%b - configuration will not be switched...\n" "${C_INFO}" "${C_RST}"
		return 0
	fi

	logf "\n%b>>> Switching%b NixOS system configuration for %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"


	set -- "${_rebuild_bin}" switch
	if is_truthy "${NO_SUB:-}"; then
		set -- "$@" --option substitute false
	fi
	[ -n "${spec:-}" ] && set -- "$@" --specialisation "${spec}"
	[ -n "${dry_switch:-}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --flake "path:${flake_root}#${_attrset}"

	print_cmd 'sudo NIX_CONFIG="extra-experimental-features = nix-command flakes"' "$@"
	# Prepend the wrapper + env exactly once
	set -- as_root env 'NIX_CONFIG=extra-experimental-features = nix-command flakes' "$@"

	if "$@"; then
		logf "\n%b✓ NixOS configuration switch success.%b\n" "${C_OK}" "${C_RST}"
		return 0
	fi
	err 1 "NixOS configuration switch failed."
}

# Switch system configuration (darwin)
_switch_darwin() {
	_attrset="${user}@${host}"
	_result_bin="./result-${host}-darwin/sw/bin/darwin-rebuild"
	_rebuild_bin=""

	if has_cmd "darwin-rebuild"; then
		_rebuild_bin="darwin-rebuild"
	fi

 	if [ -x "${_result_bin}" ]; then
		_rebuild_bin="${_result_bin}"
	fi

	if [ -z "${_rebuild_bin}" ]; then
		logf "\n%binfo:%b darwin-rebuild binary not found...\n" "${C_INFO}" "${C_RST}"
		_build_darwin
		if [ -x "${_result_bin}" ]; then
			_rebuild_bin="${_result_bin}"
		fi
	fi

	if [ -z "${_rebuild_bin}" ]; then
		err 1 "Could not locate nixos-rebuild binary."
	fi

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: --dry-run%b - configuration will not be switched...\n" "${C_INFO}" "${C_RST}"
		return 0
	fi

	logf "\n%b>>> Switching%b Nix-Darwin system configuration for %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	set -- "${_rebuild_bin}" switch
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --flake "path:${flake_root}#${_attrset}"

	print_cmd -- sudo env NIX_CONFIG='"extra-experimental-features = nix-command flakes"' "$@"

	if as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nix-Darwin switched system configuration.%b\n" "${C_OK}" "${C_RST}"
		return 0
	else
		err 1 "Nix-Darwin configuration switch failed."
	fi
}

if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found. Run {$C_CMD}make install{$C_RST} to install it."
	fi
fi

if [ -z "${TGT_USER:-}" ]; then
	err 1 "User is not set."
else
	user="${TGT_USER}"
fi

if [ -z "${TGT_HOST:-}" ]; then
	err 1 "Host is not set."
else
	host="${TGT_HOST}"
fi

if [ -z "${IS_LINUX:-}" ]; then
	err 1 "Could not determine if target system is Linux or Darwin.\n"
else
	is_linux="${IS_LINUX}"
fi

if is_truthy "${DRY_RUN:-}"; then
	dry_switch="--dry-run"
fi

if [ -n "${SWITCH_SPEC:-}" ]; then
	_set_switch_spec 
fi

if is_truthy "${DARWIN_INSTALL:-}"; then
	darwin_install="true"
else
	darwin_install="false"
fi

mode=""
prog="${0##*/}"

while [ $# -gt 0 ]; do
  case "${1}" in
    --build)   [ -z "$mode" ] || err 2 "${prog}: duplicate mode (${mode})"; mode="build"; shift ;;
    --switch)  [ -z "$mode" ] || err 2 "${prog}: duplicate mode (${mode})"; mode="switch"; shift ;;
    --) shift; break ;;
    -?*) err 2 "${prog}: invalid option: $1" ;;
    *) break ;;
  esac
done

[ -n "$mode" ] || err 2 "${prog}: no mode specified (use --build or --switch)"
[ $# -eq 0 ] || err 2 "${prog}: unexpected argument: $1"

case "${mode}" in
  build)
    if [ "${is_linux}" = "true" ]; then
      _build_nixos
    else
      _build_darwin
    fi
    exit $?
    ;;
  switch)
    if [ "${is_linux}" = "true" ]; then
			# Don't attempt to switch to a NixOS configuration outside of NixOS.
			uname -a | grep -q "NixOS" && _switch_nixos || :
    else 
			# Darwin install configured the system already, don't switch again.
      [ "${darwin_install}" = "false" ] && _switch_darwin || :
    fi
    exit $?
    ;;
esac
