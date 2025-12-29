#!/usr/bin/env sh

# Functions for building and switching standalone Home-manager configurations.

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: home.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

flake_root="$(cd "${script_dir}/.." && pwd)"
prog=""
mode=""
user=""
host=""
dry_switch=""

# Build Home-manager config
_build_home() {
  _flake_key="${user}@${host}"

  logf "\n%b>>> Building home configuration for:%b %b%s%b\n" \
    "${C_INFO}" "${C_RST}" "${C_CFG}" "${_flake_key}" "${C_RST}"

  [ "${dry_switch}" = "--dry-run" ] && \
    logf "\n%binfo: DRY_RUN%b: no result output will be created.\n" "${C_INFO}" "${C_RST}"

  set -- nix build --max-jobs auto --cores 0
  [ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
  set -- "$@" --out-link "result-${_flake_key}-home" \
    "path:${flake_root}#homeConfigurations.\"${_flake_key}\".activationPackage"

  print_cmd NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"
  NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@" || err 1 "Home build failed."

  logf "\n%b✓ Home build success.%b\n" "${C_OK}" "${C_RST}"
  logf "\n%binfo:%b Output in %b./result-%s-home%b\n" \
    "${C_INFO}" "${C_RST}" "${C_PATH}" "${_flake_key}" "${C_RST}"
}

# Switch Home-manager config
_activate_home() {
  _key="${user}@${host}"
  _activate="./result-${_key}-home/activate"

  [ "${dry_switch}" = "--dry-run" ] && {
    logf "\n%binfo: DRY_RUN%b: skipping home activation...\n" "${C_INFO}" "${C_RST}"
    return 0
  }

  [ -x "${_activate}" ] || err 1 "Home activation script not found: ${C_PATH}${_activate}${C_RST}"

  logf "\n%b>>> Activating home configuration for:%b %b%s%b\n" \
    "${C_INFO}" "${C_RST}" "${C_CFG}" "${_key}" "${C_RST}"

  print_cmd "${_activate}"
  "${_activate}" || err 1 "Home activation failed."
}

_switch_home() {
	_flake_key="${user}@${host}"
	_backup_ext="hm-backup"
	_hm_cmd=""

	if has_cmd home-manager; then
		set -- home-manager
	else
		# Online only from Nixpkgs
		set -- nix run nixpkgs#home-manager --
	fi

	logf "\n%b>>> Building home configuration for:%b %b%s%b\n" \
		"${C_INFO}" "${C_RST}" "${C_CFG}" "${user}@${host}" "${C_RST}"

	if [ "${dry_switch}" = "--dry-run" ]; then
		logf "\n%binfo: DRY_RUN%b: no result output will be created.\n" "${C_INFO}" "${C_RST}"
	fi
 
	set -- "$@" switch -b "${_backup_ext}" \
		--max-jobs auto --cores 0 
	[ -n "${dry_switch}" ] && set -- "$@" "${dry_switch}"
	set -- "$@" --flake "path:${flake_root}#${_flake_key}"

	print_cmd -- env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"

	if env NIX_CONFIG='extra-experimental-features = nix-command flakes' "$@"; then
		logf "\n%b✓ Home-manager configuration switch success.%b\n" "${C_OK}" "${C_RST}"
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

if is_truthy "${DRY_RUN:-}"; then
	dry_switch="--dry-run"
fi

mode=""
prog="${0##*/}"

while [ $# -gt 0 ]; do
  case "$1" in
    --activate)   [ -z "$mode" ] || err 2 "${prog}: duplicate mode (${mode})"; mode="activate"; shift ;;
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
	activate)
		_activate_home
		exit $?
		;;
	build)
		_build_home
		exit $?
		;;
	switch)
		_switch_home
		exit $?
		;;
esac
