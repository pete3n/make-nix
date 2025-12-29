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

# Build system (nixos)
_build_nixos() {
	_flake_key="${user}@${host}"
	logf "\n%b>>> Building system configuration for:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: DRY_RUN%b: no result output will be created.\n" "${C_INFO}" "${C_RST}"
	fi
 
	set -- nix build --max-jobs auto --cores 0 
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --out-link "result-${host}-nixos" \
		"path:${flake_root}#nixosConfigurations.\"${_flake_key}\".config.system.build.toplevel"

	print_cmd -- NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nixos build success.%b\n" "${C_OK}" "${C_RST}"
		logf "\n%binfo:%b Output in %b./result-%s-nixos%b\n" \
			"${C_INFO}" "${C_RST}" "${C_PATH}" "${host}" "${C_RST}"
		return 0
	else
		err 1 "Nixos build failed."
	fi
}

# Build system (nix-darwin)
_build_darwin() {
	_flake_key="${user}@${host}"
	logf "\n%b>>> Building system configuration for:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: DRY_RUN%b: no result output will be created.\n" "${C_INFO}" "${C_RST}"
	fi
	
	set -- nix build --max-jobs auto --cores 0
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --out-link "result-${host}-darwin" \
		"${flake_root}#darwinConfigurations.\"${_flake_key}\".system"

	print_cmd -- NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nix-Darwin build success.%b\n" "${C_OK}" "${C_RST}"
		logf "\n%binfo:%b Output in %b./result-%s-darwin%b\n" \
			"${C_INFO}" "${C_RST}" "${C_PATH}" "${host}" "${C_RST}"
		return 0
	else
		err 1 "Nix-Darwin build failed."
	fi
}

# Switch system configuration (nixos)
_switch_nixos() {
	_flake_key="${user}@${host}"
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
		logf "\n%binfo: DRY_RUN%b: configuration will not be switched...\n" "${C_INFO}" "${C_RST}"
		return 0
	fi

	logf "\n%b>>> Switching%b NixOS system configuration for %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	set -- "${_rebuild_bin}" switch \
  --option experimental-features "nix-command flakes" \
	--flake "path:${flake_root}#${_flake_key}"
	
	print_cmd -- as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ NixOS configuration switch success.%b\n" "${C_OK}" "${C_RST}"
		return 0
	else
		err 1 "Switch failed."
	fi
}

# Switch system configuration (darwin)
_switch_darwin() {
	_flake_key="${user}@${host}"
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
		logf "\n%binfo: DRY_RUN%b: configuration will not be switched...\n" "${C_INFO}" "${C_RST}"
		return 0
	fi

	logf "\n%b>>> Switching%b Nix-Darwin system configuration for %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"

	set -- "${_rebuild_bin}" switch \
  --option experimental-features "nix-command flakes" \
	--flake "path:${flake_root}#${_flake_key}"

	print_cmd -- as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if as_root env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Nix-Darwin switched system configuration.%b\n" "${C_OK}" "${C_RST}"
		return 0
	else
		err 1 "Switch failed."
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
      _switch_nixos
    else
      _switch_darwin
    fi
    exit $?
    ;;
esac
