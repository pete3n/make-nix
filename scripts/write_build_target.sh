#!/usr/bin/env sh
set -eu
env_file="${MAKE_NIX_ENV:?environment file was not set! Ensure mktemp working and in your path.}"

# shellcheck disable=SC1090
. "$env_file"

has_nix() {
  command -v nix >/dev/null 2>&1
}

if ! has_nix; then
	printf "%berror:%b nix not found in PATH. Ensure it is correctly installed.\n" "$RED" "$RESET"
	exit 1
fi

if [ -z "${system:-}" ]; then
  system="$(nix eval --impure --raw --expr 'builtins.currentSystem')"
	printf "%s\n" "$system" >> "$MAKE_NIX_ENV"
fi

case "$system" in
  *-linux) is_linux=true ;;
  *-darwin) is_linux=false ;;
  *)
    printf "error: unsupported system detected %s" "$system" >&2
    exit 1
    ;;
esac
printf "%s\n" "$is_linux" >> "$MAKE_NIX_ENV"

user="${BUILD_TARGET_USER:? error: user must be set.}"
host="${BUILD_TARGET_HOST:? error: host must be set.}"
specialisations="${BUILD_TARGET_SPECIALISATIONS:-}"

printf "Writing build-target.nix with the attributes:\n"
printf '  user              = "%s"\n' "$user"
printf '  host              = "%s"\n' "$host"
printf '  system            = "%s"\n' "$system"
printf "  isLinux           = %s\n" "$is_linux"
printf "  specialisations   = ["
if [ -n "$specialisations" ]; then
	old_ifs=$IFS
	IFS=','
	for spec in $specialisations; do
		printf " %s" "$spec"
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
	printf "  specialisations   = ["
	if [ -n "$specialisations" ]; then
		old_ifs=$IFS
		IFS=","
		for spec in $specialisations; do
			printf " %s" "$spec"
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
