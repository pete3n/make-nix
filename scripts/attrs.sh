#!/usr/bin/env sh

# Handle attribute file creation and rebuild/check previous attribute files

set -eu
script_dir="$(cd "$(dirname "$0")" && pwd)"
flake_root="$(cd "${script_dir}/.." && pwd)"

# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: attrs.sh failed to source common.sh from %s\n" "${script_dir}/common.sh" >&2
	exit 1
}

# Run cleanup if available for INT TERM or QUIT 
# Pass SIGINT as reason for cleanup
if command -v cleanup >/dev/null 2>&1; then
	trap 'cleanup 130 SIGNAL' INT TERM QUIT
fi

# All functions require the Nix binary
if ! has_nix; then
	source_nix
	if ! has_nix; then
		logf "\n%berror:%b nix not found in PATH. Are you sure Nix is installed?\n" "${RED}" "${RESET}" >&2
		return 1
	fi
fi

user=""
host=""
system=""
is_home_alone=""
is_linux=""
use_homebrew=""
use_keys=""
use_cache=""
tags=""
specs=""

_write_env() {
	printf "TGT_HOST=%s\n" "$host"
	printf "TGT_USER=%s\n" "$user"
  printf "TGT_SYSTEM=%s\n" "$system"
  printf "IS_LINUX=%s\n" "$is_linux"
  printf "HOME_ALONE=%s\n" "${is_home_alone:-}"
  printf "CFG_TAGS=%s\n" "${tags:-}"
  printf "SPECS=%s\n" "${specs:-}"
  printf "USE_HOMEBREW=%s\n" "${use_homebrew:-}"
  printf "USE_CACHE=%s\n" "${use_cache:-}"
  printf "USE_KEYS=%s\n" "${use_keys:-}"
} >> "${MAKE_NIX_ENV}"

# Avoid special chars in host and user names
_validate_ident() {
  _label=$1
  _val=$2

  case $_val in
    "" )
      err 2 "$_label is empty"
      ;;
    *[!A-Za-z0-9._-]* )
      err 2 "invalid characters in $_label: $_val"
      ;;
  esac
}

# Either use a hostname provided from commandline args or default to current hostname
if [ -z "${TGT_HOST:-}" ]; then
	host="$(hostname -s)"
	if [ -z "${host}" ]; then
		err 1 "Could not determine local hostname"
	fi
else
	host=$TGT_HOST
fi
_validate_ident "host" "${host}"

# Either user a username provided from commandline args or default to the current user
if [ -z "${TGT_USER:-}" ]; then
	user="$(whoami)"
	if [ -z "$user" ]; then
		err 1 "Could not determine local user"
	fi
else
	user=$TGT_USER
fi
_validate_ident "user" "${user}"

# Locate an attribute file in either flake_root/make-attrs/system or home-alone
# And return its path for use
_find_attrs_file() {
	_attrs_dir="system"
	_attrs_file="${flake_root}/make-attrs/${_attrs_dir}/${user}@${host}.nix"
	if [ -r "${_attrs_file}" ]; then
		printf "%s\n" "$_attrs_file"
		return 0
	fi

	_attrs_dir="home-alone"
	_attrs_file="${flake_root}/make-attrs/${_attrs_dir}/${user}@${host}.nix"
	if [ -r "${_attrs_file}" ]; then
		printf "%s\n" "$_attrs_file"
		return 0
	fi

	return 1
}

# Set global configuration vars based on env variables or autodetected defaults
# Autodetected values should only be used when 
_set_vars() {
	mode="${1}"

	# Conditionally assign a boolean value from an env var to a variable
	# This prevents overriding values from attribute with defaults when rebuilding.
	_assign_bool_if_set() {
		_envname="${1}" # Name of env var to test
		_dest="${2}" # Name of variable to set
		eval "_val=\${$_envname-}" # Safely expand with set -u and only assign if set
		if [ -n "${_val-}" ]; then 
			if is_truthy "$_val"; then
				eval "${_dest}=true"
			else
				eval "${_dest}=false"
			fi
		fi
	}

	_assign_bool_if_set HOME_ALONE is_home_alone

	# Use Homebrew for packages in Nix Darwin configuration
  _assign_bool_if_set USE_HOMEBREW use_homebrew
  if [ "$mode" = "write" ] && [ -z "${USE_HOMEBREW-}" ]; then
    : "${use_homebrew:=false}" # var should always be set to false if empty
  fi

	# Use Cache server values defined in hosts/infrax.nix for Nixos configurations
	# and in make.env for Nix-Darwin and Home-alone configurations
  _assign_bool_if_set USE_CACHE use_cache
  if [ "$mode" = "write" ] && [ -z "${USE_CACHE-}" ]; then
    : "${use_cache:=false}" # var should always be set to false if empty
  fi

	# Use trusted key values defined in hosts/infrax.nix for Nixos configurations
	# and in make.env for Nix-Darwin and Home-alone configurations
  _assign_bool_if_set USE_KEYS use_keys
  if [ "$mode" = "write" ] && [ -z "${USE_KEYS-}" ]; then
    : "${use_keys:=false}" # var should always be set to false if empty
  fi

	# Tags to pass to the Nix configuration to customize at build time
	if [ "${CFG_TAGS+x}" ]; then
		tags="${CFG_TAGS}"
	elif [ "${mode}" = "write" ]; then
		tags=""
	fi

	# Boot specialisations to build for the system configuration
	if [ "${SPECS+x}" ]; then
		specs="${SPECS}"
	elif [ "${mode}" = "write" ]; then
		specs=""
	fi

	# Target system tuple, autodetect and use host system if none provided
	# Don't override the system if checking or rebuilding an attribute set
  if [ -n "${TGT_SYSTEM-}" ]; then
    system="${TGT_SYSTEM}"
  elif [ "${mode}" = "write" ]; then
		# Create a Nix compatible system tuple e.g: aarch64-linux, x86_64-darwin
		_arch=$(uname -m)
		# Normalize arm64 and aarch64 to always be aarch64
		[ "${_arch}" = "arm64" ] && _arch=aarch64
		# Use UNAME_S if specified, otherwise detect host system and use lowercase name
		_os=$(printf "%s" "${UNAME_S:-$(uname -s)}" | tr '[:upper:]' '[:lower:]')
		system=$(printf "%s-%s" "${_arch}" "${_os}")
  else
		[ -n "${system-}" ] || err 1 "system tuple could not be determined"
  fi
	
	# Set is_linux for easy condition checks without string comparison.
	case "${system-}" in
		*-linux) is_linux=true ;;
		*-darwin) is_linux=false ;;
		"")
			err 1 "Cannot determine system type"
			;;
		*)
			err 1 "Unsupported system detected" "${system}"
			;;
	esac
}

# Assign global configuration values be evaluating an attribute file using Nix
_eval_vars() {
	_attrs_file="${1}"

  if ! command -v nix-instantiate >/dev/null 2>&1; then
    source_nix
  fi

  if ! command -v nix-instantiate >/dev/null 2>&1; then
    err 1 "nix-instantiate not found. Cannot validate Nix syntax"
  fi

  if ! _out=$(nix-instantiate --parse "$_attrs_file" 2>&1); then
    err 1 "Invalid attrs file ${CYAN-}${_attrs_file}${RESET-}:\n${_out}"
  fi

	# Convert variable to boolean
	_make_bool() {
		_varname="${1}"
		eval "_val=\${$_varname-}" # Safely expand with set -u and only assign if set
		if is_truthy "$_val"; then
			eval "${_varname}=true"
		else
			eval "${_varname}=false"
		fi }

	_nix_eval() {
		_expr="${1}"
		if ! _out=$(
			NIX_CONFIG='extra-experimental-features = nix-command flakes' \
			command nix eval --raw --impure --expr "${_expr}" 2>&1
		); then
			err 1 "nix eval failed while reading attrs file\ 
				${CYAN-}${_attrs_file}${RESET-}:\n${_out}\nexpr:\n${_expr}"
		fi
		printf '%s\n' "${_out}"
	}

  _path_expr="\"${_attrs_file}\""
	_base="let attr = import ${_path_expr} {}; in attr"

  system="$(_nix_eval "${_base}.system or \"\"")"

	is_home_alone="$(_nix_eval "builtins.toString (${_base}.isHomeAlone or false)")"
	_make_bool is_home_alone
	use_homebrew="$(_nix_eval "builtins.toString (${_base}.useHomebrew or false)")"
	_make_bool use_homebrew
	use_keys="$(_nix_eval "builtins.toString (${_base}.useKeys or false)")"
	_make_bool use_keys
	use_cache="$(_nix_eval "builtins.toString (${_base}.useCache or false)")"
	_make_bool use_cache

  tags="$(_nix_eval "builtins.concatStringsSep \",\" (${_base}.tags or [])")"
  specs="$(_nix_eval "builtins.concatStringsSep \",\" (${_base}.specialisations or [])")"

	logf "\n${BLUE}Reading attributes:${RESET}\nsystem: %s\nis_home_alone: %s\nuse_homebrew: %s\nuse_keys: %s\nuse_cache: %s\ntags: %s\nspecs: %s\n" \
		"${system}" "${is_home_alone}" "${use_homebrew}" "${use_keys}" "${use_cache}" "${tags}" "${specs}"
}

# Kludge to prevent Git tree from being marked as dirty
_commit_config() {
	_filename="${1}"
	if [ -f "${_filename}" ]; then
		logf "%binfo:%b committing %b%s%b to git tree.\n" "$BLUE" "$RESET" "$MAGENTA" "${_filename}" "$RESET"
		git add -f "${_filename}"
		GIT_AUTHOR_NAME="make-nix" \
		GIT_AUTHOR_EMAIL="make-nix@bot" \
		GIT_COMMITTER_NAME="make-nix" \
		GIT_COMMITTER_EMAIL="make-nix@bot" \
		git commit -m "build: Make-nix automated commit to keep git tree clean" || true
	else
		logf "\n%berror:%b %b%s%b not found!\n" "$RED" "$RESET" "$MAGENTA" "${_filename}" "$RESET"
		exit 1
	fi
}

# Write a Nix attribute set for a home-alone configuration
_write_home_alone() {
	_home_alone_config="${1}" 
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"$BLUE" "$RESET" "$MAGENTA" "$_home_alone_config" "$RESET"
	logf '  user              = "%s"\n' "$user"
	logf '  host              = "%s"\n' "$host"
	logf '  system            = "%s"\n' "$system"
	logf '  isHomeAlone       = %s\n' "$is_home_alone"
	logf '  useHomebrew       = %s\n' "$use_homebrew"
	logf '  useCache          = %s\n' "$use_cache"
	logf '  useKeys           = %s\n' "$use_keys"
	logf "  tags              = ["
	if [ -n "${tags}" ]; then
		set -f
		_old_ifs=$IFS
		IFS=','
		for _tag in $tags; do
			logf ' "%s"' "${_tag}"
		done
		IFS="${_old_ifs}"
		set +f
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
		if [ -n "${tags}" ]; then
			set -f
			_old_ifs=$IFS
			IFS=','
			for _tag in $tags; do
				logf ' "%s"' "${_tag}"
			done
			IFS="${_old_ifs}"
			set +f
		fi
		printf " ];\n"
		printf '}\n'
	} >"${_home_alone_config}"
}

# Write a Nix attribute set for a NixOS or Darwin system configuration
_write_system() {
	_system_config="${1}"
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"$BLUE" "$RESET" "$MAGENTA" "$_system_config" "$RESET"
	logf '  user              = "%s"\n' "$user"
	logf '  host              = "%s"\n' "$host"
	logf '  system            = "%s"\n' "$system"
	logf '  isHomeAlone       = %s\n' "$is_home_alone"
	logf '  useHomebrew       = %s\n' "$use_homebrew"
	logf '  useCache          = %s\n' "$use_cache"
	logf '  useKeys           = %s\n' "$use_keys"
	logf "  tags              = ["
	if [ -n "${tags}" ]; then
		set -f
		_old_ifs=$IFS
		IFS=','
		for _tag in $tags; do
			logf ' "%s"' "${_tag}"
		done
		IFS="${_old_ifs}"
		set +f
	fi
	logf " ]\n"

	logf "  specialisations   = ["
	if [ -n "${specs}" ]; then
		_old_ifs=$IFS
		IFS=','
		for _spec in $specs; do
			logf ' "%s"' "${_spec}"
		done
		IFS="${_old_ifs}"
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
		if [ -n "${tags}" ]; then
			set -f
			_old_ifs=$IFS
			IFS=','
			for _tag in $tags; do
				logf ' "%s"' "${_tag}"
			done
			IFS="${_old_ifs}"
			set +f
		fi
		printf " ];\n"

		printf "  specialisations = ["
		if [ -n "${specs}" ]; then
			_old_ifs=$IFS
			IFS=','
			for _spec in $specs; do
				logf ' "%s"' "${_spec}"
			done
			IFS="${_old_ifs}"
		fi
		printf " ];\n"

		printf '}\n'
	} >"$_system_config"
}

# Load a configuration attribute set based on user and host names. 
# Evaluate the configuration using Nix eval as appropriate for the configuraiton type.
check_attrs() {
	_cfg_key="${user}@${host}"
	if _attrs_file="$(_find_attrs_file)"; then
		logf "Nix attribute file: %b%s%b\n" "${CYAN}" "${_attrs_file}" "${RESET}"
	else
		err 1 "Nix attribute check failed, attrs file was not found for:\
			${CYAN}${_cfg_key}${RESET}"
	fi

	_eval_vars "${_attrs_file}"
	_write_env

	_has_attr() {
		_attr="${1}" # homeConfigurations | nixosConfigurations | darwinConfigurations
		_cfg_key="${2}" # user@host
		_flake_path="path:${flake_root}"

		if ! _out=$(
			NIX_CONFIG='extra-experimental-features = nix-command flakes' \
			command nix eval --impure --json "${_flake_path}#${_attr}" \
				--apply "config: builtins.hasAttr \"${_cfg_key}\" config" 2>&1
		); then
			err 1 "nix eval failed while checking \
				${CYAN}${_flake_path}#${_attr}.${_cfg_key}${RESET}:\n${_out}"
		fi

		printf '%s\n' "$_out"
	}

	_eval_drv() {
		_expr="${1}"
		logf "\n%bEval command:%b NIX_CONFIG='extra-experimental-features = nix-command flakes' nix eval --no-warn-dirty --impure --raw %b%s%b\n" \
    "${BLUE}" "${RESET}" "${CYAN}" "${_expr}" "${RESET}"
		NIX_CONFIG='extra-experimental-features = nix-command flakes' \
    nix eval --no-warn-dirty --impure --raw "${_expr}"
	}

  if [ "$(_has_attr "homeConfigurations" "${_cfg_key}")" != "true" ]; then
    err 1 "${CYAN}homeConfigurations.${_cfg_key}${RESET} not found in flake outputs" 
  fi

	logf "\n%bChecking%b %bhomeConfigurations.%s%b ...\n" "${BLUE}" "${RESET}" "${CYAN}" "${_cfg_key}" "${RESET}"
  if ! _eval_ok="$(_eval_drv ".#homeConfigurations.\"${_cfg_key}\".activationPackage.drvPath")"; then
    err 1 "Failed evaluating home activation drvPath for: ${CYAN} ${_cfg_key} ${RESET}"
  fi
	logf "%b✅ success:%b eval passed %s\n" "$GREEN" "$RESET" "${_eval_ok}"

  # Don't attempt to evaluate a system configuration for a home-alone target.
  if [ "${is_home_alone:-false}" = "true" ]; then
    logf "\nHome-alone configuration: skipping system configuration checks.\n"
    return 0
  fi

  if [ "$(_has_attr "nixosConfigurations" "${_cfg_key}")" = "true" ]; then
    logf "\n%bChecking%b %bnixosConfigurations.%s%b ...\n" "${BLUE}" "${RESET}" "${CYAN}" "${_cfg_key}" "${RESET}"
    if ! _eval_ok="$(_eval_drv ".#nixosConfigurations.\"${_cfg_key}\".config.system.build.toplevel.drvPath")"; then
			err 1 "Failed evaluating NixOS toplevel drvPath for ${CYAN} ${_cfg_key} ${RESET}"
    fi
		logf "%b✅ success:%b eval passed %s\n" "$GREEN" "$RESET" "${_eval_ok}"
		return 0
  fi

  if [ "$(_has_attr "darwinConfigurations" "${_cfg_key}")" = "true" ]; then
    logf "\n%bChecking%b %b darwinConfigurations.%s%b ...\n" "${BLUE}" "${RESET}" "${CYAN}" "${_cfg_key}" "${RESET}"
		if ! _eval_ok="$(_eval_drv ".#darwinConfigurations.\"${_cfg_key}\".system.drvPath")"; then
			err 1 "Failed evaluating Darwin system drvPath for ${CYAN} ${_cfg_key} ${RESET}"
    fi
		logf "%b✅ success:%b eval passed %s\n" "$GREEN" "$RESET" "${_eval_ok}"
    return 0
  fi

  err 1 "No system configuration found for ${CYAN}${_cfg_key}${RESET}"
}

# Write a configuration attribute set to pass into the Nix flake.
write_attrs() {
	# NixOS or Nix-Darwin indicate we will be using a system configuration 
	# Installing Nix-Darwin also indicates we will be using a system configuration
	if has_nixos || has_nix_darwin || is_truthy "${INSTALL_DARWIN:-}"; then
		is_home_alone=false
	else
		is_home_alone=true
	fi

	_set_vars "write"

	logf "\n%b>>> Writing Nix configuration.%b\n" "$BLUE" "$RESET"
	_write_env
	if [ "${is_home_alone}" = true ]; then
		if _write_home_alone "$(resolve_path "./make-attrs/home-alone/$user@$host.nix")"; then
			_commit_config "${_home_alone_config}"
		else
			err 1 "Could not write configuration: ${CYAN}${_home_alone_config}${RESET}"
		fi

		else
			if _write_system "$(resolve_path "./make-attrs/system/$user@$host.nix")"; then
				_commit_config "$_system_config"
			else
				err 1 "Could not write configuration: ${CYAN}${_system_config}${RESET}"
			fi
	fi
}

# Load a configuration attribute set based on user and host names. 
# Modify it with any set env vars and re-write it to pass into the Nix flake.
rebuild_attrs() { 
	_cfg_key="${user}@${host}"
	if _attrs_file="$(_find_attrs_file)"; then
		logf "Nix attribute file: %b%s%b\n" "${CYAN}" "${_attrs_file}" "${RESET}"
	else
		err 1 "Failed to read nix attribute file: ${CYAN}${_cfg_key}${RESET}"
	fi

	_eval_vars "${_attrs_file}"
	_set_vars "rebuild" # Override attribute file with new command line vars
	_write_env

	logf "\n%b>>> Writing Nix configuration.%b\n" "$BLUE" "$RESET"
	if [ "$is_home_alone" = true ]; then
		if _write_home_alone "$(resolve_path "./make-attrs/home-alone/$user@$host.nix")"; then
			_commit_config "$_home_alone_config"
		else
			err 1 "Could not write configuration: ${CYAN}${_home_alone_config}${RESET}"
		fi

		else
			err 1 "Could not write configuration: ${CYAN}${_system_config}${RESET}"
		fi
	fi
}

case "$1" in
	--check)
		check_attrs
		;;
	--write)
		write_attrs
		;;
	--rebuild)
		rebuild_attrs
		;;
	*)
		err 1 "Makefile error: attrs target called without --check | --write | --rebuild"
		;;
esac
