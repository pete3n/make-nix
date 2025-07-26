#!/usr/bin/env sh
set -eu

env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

if [ -z "${TGT_USER:-}" ]; then
	user="$(whoami)"
	if [ -z "$user" ]; then
		printf "%berror:%b could not determine local user." "$RED" "$RESET"
		exit 1 
	else
		printf "TGT_USER=%s\n" "$user" >> "$MAKE_NIX_ENV"
	fi
else
	user=$TGT_USER
fi

if [ -z "${TGT_HOST:-}" ]; then
	host="$(hostname)"
	if [ -z "$host" ]; then
		printf "%berror:%b could not determine local hostname." "$RED" "$RESET"
		exit 1 
	fi
	printf "TGT_HOST=%s\n" "$host" >> "$MAKE_NIX_ENV"
else
	host=$TGT_HOST
fi

if ! [ "${TGT_SPEC+x}" ]; then
	TGT_SPEC=""
else
	printf "TGT_SPEC=%s\n" "$TGT_SPEC" >> "$MAKE_NIX_ENV"
fi

has_nix() {
  command -v nix >/dev/null 2>&1
}

if ! has_nix; then
	printf "%berror:%b nix not found in PATH. Ensure it is correctly installed.\n" "$RED" "$RESET"
	exit 1
fi

if [ -z "${TGT_SYSTEM:-}" ]; then
  system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
	printf "TGT_SYSTEM=%s\n" "$system" >> "$MAKE_NIX_ENV"
else
	system=$TGT_SYSTEM
fi

case "$system" in
  *-linux) is_linux=true ;;
  *-darwin) is_linux=false ;;
  *)
    printf "error: unsupported system detected %s" "$TGT_SYSTEM" >&2
    exit 1
    ;;
esac
printf "IS_LINUX=%s\n" "$is_linux" >> "$MAKE_NIX_ENV"

printf "Writing build-target.nix with the attributes:\n"
printf '  user              = "%s"\n' "$user"
printf '  host              = "%s"\n' "$host"
printf '  system            = "%s"\n' "$system"
printf "  isLinux           = %s\n" "$is_linux"
printf "  specialisations   = ["
if [ -n "$TGT_SPEC" ]; then
	old_ifs=$IFS
	IFS=','
	for spec in $TGT_SPEC; do
		printf ' "%s"' "$spec"
	done
	IFS=$old_ifs
fi
printf " ]\n"

{
	printf "{ ... }:\n{\n"
	printf '  user = "%s";\n' "$user"
	printf '  host = "%s";\n' "$host"
	printf '  system = "%s";\n' "$system"
	printf '  isLinux = %s;\n' "$is_linux"
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
} >build-target.nix

# Kludge to prevent Git tree from being marked as dirty
if [ -f build-target.nix ]; then
	git add -f build-target.nix
	git commit -m "build: automated commit by make-nix to keep tree clean" || true
else
	printf "\n build-target.nix not found!\n"
	exit 1
fi
