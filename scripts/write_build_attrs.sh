#!/usr/bin/env sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

trap 'cleanup_on_halt $?' EXIT INT TERM QUIT

if [ -z "${TGT_USER:-}" ]; then
	user="$(whoami)"
	if [ -z "$user" ]; then
		logf "\n%berror:%b could not determine local user.\n" "$RED" "$RESET"
		exit 1 
	else
		printf "TGT_USER=%s\n" "$user" >> "$MAKE_NIX_ENV"
	fi
else
	user=$TGT_USER
fi

if [ "${TGT_TAGS+x}" ]; then
	printf "TGT_TAGS=%s\n" "$TGT_TAGS" >> "$MAKE_NIX_ENV"
else
	TGT_TAGS=""
fi

if [ -z "${TGT_HOST:-}" ]; then
	host="$(uname -n)"
	if [ -z "$host" ]; then
		logf "\n%berror:%b could not determine local hostname.\n" "$RED" "$RESET"
		exit 1 
	fi
	printf "TGT_HOST=%s\n" "$host" >> "$MAKE_NIX_ENV"
else
	host=$TGT_HOST
fi

if [ "${TGT_SPEC+x}" ]; then
	printf "TGT_SPEC=%s\n" "$TGT_SPEC" >> "$MAKE_NIX_ENV"
else
	TGT_SPEC=""
fi

check_for_nix

if [ -z "${TGT_SYSTEM:-}" ]; then
  system="$(nix --extra-experimental-features nix-command eval --impure --raw --expr 'builtins.currentSystem')"
	printf "TGT_SYSTEM=%s\n" "$system" >> "$MAKE_NIX_ENV"
else
	system=$TGT_SYSTEM
fi

case "$system" in
  *-linux) is_linux=true ;;
  *-darwin) is_linux=false ;;
  *)
    logf "\n%berror:%b unsupported system detected %s\n" "$RED" "$RESET" "$TGT_SYSTEM" >&2
    exit 1
    ;;
esac
printf "IS_LINUX=%s\n" "$is_linux" >> "$MAKE_NIX_ENV"

if is_truthy "${HOME_ALONE:-}"; then
	is_home_alone=true
else
	is_home_alone=false
fi

logf "Writing build-attrs.nix with the attributes:\n"
logf '  user              = "%s"\n' "$user"
logf '  host              = "%s"\n' "$host"
logf '  system            = "%s"\n' "$system"
logf '  isLinux           = %s\n' "$is_linux"
logf '  isHomeAlone       = %s\n' "$is_home_alone"

logf "  tags              = ["
if [ -n "$TGT_TAGS" ]; then
	old_ifs=$IFS
	IFS=','
	for tag in $TGT_TAGS; do
		logf ' "%s"' "$tag"
	done
	IFS=$old_ifs
fi
logf " ]\n"

logf "  specialisations   = ["
if [ -n "$TGT_SPEC" ]; then
	old_ifs=$IFS
	IFS=','
	for spec in $TGT_SPEC; do
		logf ' "%s"' "$spec"
	done
	IFS=$old_ifs
fi
logf " ]\n"

{
	printf "{ ... }:\n{\n"
	printf '  user = "%s";\n' "$user"
	printf '  host = "%s";\n' "$host"
	printf '  system = "%s";\n' "$system"
	printf '  isLinux = %s;\n' "$is_linux"
	printf '  isHomeAlone = %s;\n' "$is_home_alone"

	printf "  tags = ["
	if [ -n "$TGT_TAGS" ]; then
		old_ifs=$IFS
		IFS=","
		for tag in $TGT_TAGS; do
			printf ' "%s"' "$tag"
		done
		IFS=$old_ifs
	fi
	printf " ];\n"

	printf "  specialisations = ["
	if [ -n "$TGT_SPEC" ]; then
		old_ifs=$IFS
		IFS=","
		for spec in $TGT_SPEC; do
			printf ' "%s"' "$spec"
		done
		IFS=$old_ifs
	fi
	printf " ];\n"

	printf '}\n'
} >build-attrs.nix

# Kludge to prevent Git tree from being marked as dirty
if [ -f build-attrs.nix ]; then
	git add -f build-attrs.nix
	git commit -m "build: Make-nix automated commit to keep git tree clean" || true
else
	logf "\n%berror:%b build-attrs.nix not found!\n" "$RED" "$RESET"
	exit 1
fi
