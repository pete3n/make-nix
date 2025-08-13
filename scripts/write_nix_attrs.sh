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
		printf "TGT_USER=%s\n" "$user" >>"$MAKE_NIX_ENV"
	fi
else
	user=$TGT_USER
fi

if [ "${TGT_TAGS+x}" ]; then
	printf "TGT_TAGS=%s\n" "$TGT_TAGS" >>"$MAKE_NIX_ENV"
else
	TGT_TAGS=""
fi

if [ -z "${TGT_HOST:-}" ]; then
	host="$(hostname -s)"
	if [ -z "$host" ]; then
		logf "\n%berror:%b could not determine local hostname.\n" "$RED" "$RESET"
		exit 1
	fi
	printf "TGT_HOST=%s\n" "$host" >>"$MAKE_NIX_ENV"
else
	host=$TGT_HOST
fi

if [ -z "${TGT_SYSTEM:-}" ]; then
	arch=$(uname -m)
	[ "$arch" = "arm64" ] && arch=aarch64
  os=$(printf "%s" "${UNAME_S:-$(uname -s)}" | tr '[:upper:]' '[:lower:]')
  system=$(printf "%s-%s" "$arch" "$os")
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
printf "IS_LINUX=%s\n" "$is_linux" >>"$MAKE_NIX_ENV"

if [ "${TGT_SPEC+x}" ]; then
	printf "TGT_SPEC=%s\n" "$TGT_SPEC" >>"$MAKE_NIX_ENV"
else
	TGT_SPEC=""
fi

if ! has_nix; then
	source_nix
	if ! has_nix; then
		printf "\n%berror:%b Nix not detected. Cannot continue.\n" "$RED" "$RESET"
		exit 1
	fi
fi

nix_darwin_install=false
if is_truthy "${NIX_DARWIN:-}"; then
	nix_darwin_install=true
fi

# If we don't have NixOS and we don't have Nix-Darwin, and we aren't going to install
# Nix-Darwin, then we are using Home-manager standalone.
if has_nixos || has_nix_darwin || [ "$nix_darwin_install" = true ]; then
	is_home_alone=false
else
	is_home_alone=true
fi

# If the user specifies HOME_ALONE (for a different system build), then it overrides
# any auto-detection.
if [ -n "${HOME_ALONE-}" ]; then
	if is_truthy "$HOME_ALONE"; then
		is_home_alone=true
	else
		is_home_alone=false
	fi
fi

if is_truthy "${USE_HOMEBREW:-}"; then
	use_homebrew=true
else
	use_homebrew=false
fi

if is_truthy "${USE_CACHE:-}"; then
	use_cache=true
else
	use_cache=false
fi

if is_truthy "${USE_KEYS:-}"; then
	use_keys=true
else
	use_keys=false
fi

# Kludge to prevent Git tree from being marked as dirty
commit_config() {
	if [ -f "$1" ]; then
		logf "%binfo:%b committing %b%s%b to git tree.\n" "$BLUE" "$RESET" "$MAGENTA" "$1" "$RESET"
		git add -f "$1"
		GIT_AUTHOR_NAME="make-nix" \
			GIT_AUTHOR_EMAIL="make-nix@bot" \
			GIT_COMMITTER_NAME="make-nix" \
			GIT_COMMITTER_EMAIL="make-nix@bot" \
			git commit -m "build: Make-nix automated commit to keep git tree clean" || true
	else
		logf "\n%berror:%b %b%s%b not found!\n" "$RED" "$RESET" "$MAGENTA" "$1" "$RESET"
		exit 1
	fi
}

# Standalone Home-manager configuration
home_alone_config="$(resolve_path "./make-attrs/home-alone/$user@$host.nix")"
write_home_alone() {
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"$BLUE" "$RESET" "$MAGENTA" "$home_alone_config" "$RESET"
	logf '  user              = "%s"\n' "$user"
	logf '  host              = "%s"\n' "$host"
	logf '  system            = "%s"\n' "$system"
	logf '  isHomeAlone       = %s\n' "$is_home_alone"
	logf '  useHomebrew       = %s\n' "$use_homebrew"
	logf '  useCache          = %s\n' "$use_cache"
	logf '  useKeys           = %s\n' "$use_keys"
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

	{
		printf "{ ... }:\n{\n"
		printf '  user = "%s";\n' "$user"
		printf '  host = "%s";\n' "$host"
		printf '  system = "%s";\n' "$system"
		printf '  isHomeAlone = %s;\n' "$is_home_alone"
		printf '  useHomebrew = %s;\n' "$use_homebrew"
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
		printf '}\n'
	} >"$home_alone_config"
}

# System configuration
system_config="$(resolve_path "./make-attrs/system/$user@$host.nix")"
write_system() {
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"$BLUE" "$RESET" "$MAGENTA" "$system_config" "$RESET"
	logf '  user              = "%s"\n' "$user"
	logf '  host              = "%s"\n' "$host"
	logf '  system            = "%s"\n' "$system"
	logf '  isHomeAlone       = %s\n' "$is_home_alone"
	logf '  useHomebrew       = %s\n' "$use_homebrew"
	logf '  useCache          = %s\n' "$use_cache"
	logf '  useKeys           = %s\n' "$use_keys"
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
		printf '  isHomeAlone = %s;\n' "$is_home_alone"
		printf '  useHomebrew = %s;\n' "$use_homebrew"
		printf '  useCache = %s;\n' "$use_cache"
		printf '  useKeys = %s;\n' "$use_keys"
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
	} >"$system_config"
}

logf "\n%b>>> Writing Nix configuration.%b\n" "$BLUE" "$RESET"
if [ "$is_home_alone" = true ]; then
	if write_home_alone; then
		commit_config "$home_alone_config"
	else
		logf "\n%berror: %b could not write configuration: %b%s%b\n" \
			"$RED" "$RESET" "$MAGENTA" "$home_alone_config" "$RESET"
		exit 1
	fi

	else
		if write_system; then
			commit_config "$system_config"
		else
			logf "\n%berror: %b could not write configuration: %b%s%b\n" \
				"$RED" "$RESET" "$MAGENTA" "$system_config" "$RESET"
			exit 1
		fi

fi
