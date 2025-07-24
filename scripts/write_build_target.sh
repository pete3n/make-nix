#!/usr/bin/env sh
set -eu

: "${host:?host is required, but was not passed.}"
: "${user:?user is required, but was not passed.}"
: "${system:?system is required, but was not passed.}"

if [ -z "$host" ] || [ -z "$user" ] || [ -z "$system" ]; then
	exit 1
fi

spec_list=""
for arg in "$@"; do
	case $arg in
	spec=*)
		spec_list=${arg#spec=}
		;;
	*)
		printf 'Unknown argument: %s\n' "$arg" >&2
		exit 1
		;;
	esac
done

isLinux=false
case "$system" in
x86_64-linux | aarch64-linux) isLinux=true ;;
esac

printf "Writing build-target.nix with the attributes:\n"
printf "  user              = %s\n" "$user"
printf "  host              = %s\n" "$host"
printf "  system            = %s\n" "$system"
printf "  isLinux           = %s\n" "$isLinux"

if [ -n "$spec_list" ]; then
	printf "  specialisations   = ["
	old_ifs=$IFS
	IFS=','
	for spec in $spec_list; do
		printf ' %s' "$spec"
	done
	IFS=$old_ifs
	printf ' ]\n'
else
	printf "  specialisations   = [ ]\n"
fi

{
	printf '{ ... }:\n{\n'
	printf '  user = "%s";\n' "$user"
	printf '  host = "%s";\n' "$host"
	printf '  system = "%s";\n' "$system"
	printf '  isLinux = %s;\n' "$isLinux"
	printf '  specialisations = ['
	old_ifs=$IFS
	IFS=','
	if [ -n "$spec_list" ]; then
		for spec in $spec_list; do
			printf ' "%s"' "$spec"
		done
		IFS=$old_ifs
	fi
	printf ' ];\n'
	printf '}\n'
} >build-target.nix

# Kludge to prevent Git tree from being marked as dirty
if [ -f build-target.nix ]; then
	if [ -f .git/info/exclude ]; then
		grep -qxF 'build-target.nix' .git/info/exclude || printf 'build-target.nix' >>.git/info/exclude
	else
		mkdir -p .git/info
		printf 'build-target.nix' >>.git/info/exclude
	fi
	git add -f build-target.nix
else
	printf "\n build-target.nix not found!\n"
	exit 1
fi
