#!/usr/bin/env sh

# Handle attribute file creation and rebuild/check previous attribute files

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$script_dir/common.sh" || {
	printf "ERROR: attrs.sh failed to source common.sh from %s\n" \
	"${script_dir}/common.sh" >&2
	exit 1
}

trap 'cleanup 130 "SIGNAL"' INT TERM QUIT

# All functions require the Nix binary
if ! has_cmd "nix"; then
	source_nix
	if ! has_cmd "nix"; then
		err 1 "nix not found in PATH. Install with make install."
	fi
fi

flake_root="$(cd "${script_dir}/.." && pwd)"
prog="${0##*/}"
mode=""
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
	host="$(uname -n)"
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

# Write out vars to env file to persist across scripts
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
		*-linux) is_linux="true" ;;
		*-darwin) is_linux="false" ;;
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

	# nix-instantiate is required to parse the attribute file for syntax errors
  if ! has_cmd "nix-instantiate"; then
		# Attempt to fix PATH issues
    source_nix
  fi

  if ! has_cmd "nix-instantiate"; then
    err 1 "nix-instantiate not found. Cannot validate Nix syntax"
  fi

  if ! _out=$(nix-instantiate --parse "$_attrs_file" 2>&1); then
    err 1 "Invalid attrs file ${C_PATH}${_attrs_file}${C_RST}:\n${_out}"
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
				${C_PATH}${_attrs_file}${C_RST}:\n${_out}\nexpr:\n${_expr}"
		fi
		printf '%s\n' "${_out}"
	}

  _path_expr="\"${_attrs_file}\""
	_base="let attr = import ${_path_expr} {}; in attr"

  _user="$(_nix_eval "${_base}.user or \"\"")"
	if ! [ "${_user}" = "${user}" ]; then
		err 1 "The user specified in the attribute file: ${C_CFG}${_user}${C_RST} " \
					"does not match the target user: ${C_CFG}${user}${C_RST}"
	fi
  _host="$(_nix_eval "${_base}.host or \"\"")"
	if ! [ "${_host}" = "${host}" ]; then
		err 1 "The host specified in the attribute file: ${C_CFG}${_host}${C_RST} " \
					"does not match the target host: ${C_CFG}${host}${C_RST}"
	fi
  system="$(_nix_eval "${_base}.system or \"\"")"

	is_home_alone="$(_nix_eval "builtins.toString (${_base}.isHomeAlone or false)")"
	_make_bool is_home_alone
	is_linux="$(_nix_eval "builtins.toString (${_base}.isLinux or false)")"
	_make_bool is_linux
	use_homebrew="$(_nix_eval "builtins.toString (${_base}.useHomebrew or false)")"
	_make_bool use_homebrew
	use_keys="$(_nix_eval "builtins.toString (${_base}.useKeys or false)")"
	_make_bool use_keys
	use_cache="$(_nix_eval "builtins.toString (${_base}.useCache or false)")"
	_make_bool use_cache

  tags="$(_nix_eval "builtins.concatStringsSep \",\" (${_base}.tags or [])")"
  specs="$(_nix_eval "builtins.concatStringsSep \",\" (${_base}.specialisations or [])")"

	_fmt="\n${C_INFO}Reading attributes:${C_RST}\n"
	_fmt="${_fmt} user: %b%s%b\n host: %b%s%b\n system: %b%s%b\n"
	_fmt="${_fmt} is_linux: %b%s%b\n is_home_alone: %b%s%b\n use_homebrew: %b%s%b\n"
	_fmt="${_fmt} use_keys: %b%s%b\n use_cache: %b%s%b\n"
	_fmt="${_fmt} tags: %b%s%b\n specs: %b%s%b\n"

	logf "$_fmt" \
		"${C_CFG}" "${user}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"\
		"${C_CFG}" "${system}" "${C_RST}" "${C_CFG}" "${is_linux}" "${C_RST}"\
		"${C_CFG}" "${is_home_alone}" "${C_RST}" "${C_CFG}" "${use_homebrew}" "${C_RST}"\
		"${C_CFG}" "${use_keys}" "${C_RST}" "${C_CFG}" "${use_cache}" "${C_RST}"\
		"${C_CFG}" "${tags}" "${C_RST}" "${C_CFG}" "${specs}" "${C_RST}"
}

# Prevent Git tree from being marked as dirty
_commit_config() {
  _filename="${1}"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || err 1 "Not inside a git work tree. Flakes require git."
  
	if [ ! -f "${_filename}" ]; then
		err 1 "Git cannot add ${C_PATH}${_filename}${C_RST} file was not found"
  fi
  git add -f "${_filename}"

  # If no changes were staged, then do nothing
  if git diff --cached --quiet -- "${_filename}"; then
    logf "\n%binfo:%b %b%s%b unchanged, skipping commit.\n"\
			"$C_INFO" "$C_RST" "${C_PATH}" "${_filename}" "${C_RST}"
    return 0
  fi

  logf "%binfo:%b committing %b%s%b to git tree.\n" \
    "${C_INFO}" "${C_RST}" "${C_PATH}" "${_filename}" "${C_RST}"

  GIT_AUTHOR_NAME="make-nix" \
  GIT_AUTHOR_EMAIL="make-nix@bot" \
  GIT_COMMITTER_NAME="make-nix" \
  GIT_COMMITTER_EMAIL="make-nix@bot" \
  git commit -m "build: Make-nix automated commit to keep git tree clean"
}

# Write a Nix attribute set for a home-alone configuration
_write_home_alone() {
	_home_alone_config="${1}" 
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"${C_INFO}" "${C_RST}" "${C_PATH}" "${_home_alone_config}" "${C_RST}"
	logf '  user              = "%s"\n' "${user}"
	logf '  host              = "%s"\n' "${host}"
	logf '  system            = "%s"\n' "${system}"
	logf "  isLinux           = %s\n" "${is_linux}"
	logf "  isHomeAlone       = %s\n" "${is_home_alone}"
	logf "  useHomebrew       = %s\n" "${use_homebrew}"
	logf "  useCache          = %s\n" "${use_cache}"
	logf "  useKeys           = %s\n" "${use_keys}"
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
		printf '  user = "%s";\n' "${user}"
		printf '  host = "%s";\n' "${host}"
		printf '  system = "%s";\n' "${system}"
		printf "  isLinux = %s;\n" "${is_linux}"
		printf "  isHomeAlone = %s;\n" "${is_home_alone}"
		printf "  useHomebrew = %s;\n" "${use_homebrew}"
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
	} > "${_home_alone_config}"
}

# Write a Nix attribute set for a NixOS or Darwin system configuration
_write_system() {
	_system_config="${1}"
	logf "\n%binfo:%b writing %b%s%b with:\n" \
		"${C_INFO}" "${C_RST}" "${C_PATH}" "${_system_config}" "${C_RST}"
	logf '  user              = "%s"\n' "${user}"
	logf '  host              = "%s"\n' "${host}"
	logf '  system            = "%s"\n' "${system}"
	logf "  isLinux           = %s\n" "${is_linux}"
	logf "  isHomeAlone       = %s\n" "${is_home_alone}"
	logf "  useHomebrew       = %s\n" "${use_homebrew}"
	logf "  useCache          = %s\n" "${use_cache}"
	logf "  useKeys           = %s\n" "${use_keys}"
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
		printf '  user = "%s";\n' "${user}"
		printf '  host = "%s";\n' "${host}"
		printf '  system = "%s";\n' "${system}"
		printf "  isLinux = %s;\n" "${is_linux}"
		printf "  isHomeAlone = %s;\n" "${is_home_alone}"
		printf "  useHomebrew = %s;\n" "${use_homebrew}"
		printf "  useCache = %s;\n" "${use_cache}"
		printf "  useKeys = %s;\n" "${use_keys}"
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

		printf "}\n"
	} >"${_system_config}"
}

# Read the Nix attribute file and update the env vars
read_attrs() {
	_flake_key="${user}@${host}"
	if _attrs_file="$(_find_attrs_file)"; then
		logf "Nix attribute file: %b%s%b\n" "${C_PATH}" "${_attrs_file}" "${C_RST}"
	else
		_msg="Failed to read Nix attributes, attrs file was not found for: "
		_msg="${_msg}${C_CFG}${_flake_key}${C_RST}"
		err 1 "${_msg}"
	fi

	_eval_vars "${_attrs_file}"
	_write_env
}

# Load a configuration attribute set based on user and host names. 
# Evaluate the configuration using Nix eval as appropriate for the configuraiton type.
check_attrs() {
	_checks="${1}"
	read_attrs

	# Determine if flake has an attribute; returns "true" or "false"
	_has_attr() {
		_attr="${1}"	# homeConfigurations | nixosConfigurations | darwinConfigurations
		_flake_key="${2}"	# user@host
		_flake_path="path:${flake_root}"

		if ! _out="$(
			NIX_CONFIG='extra-experimental-features = nix-command flakes' \
			command nix eval --impure --json \
				"${_flake_path}#${_attr}" \
				--apply "config: builtins.hasAttr \"${_flake_key}\" config"
		)"; then
			err 1 "nix eval failed while checking ${C_CFG}${_attr}.${_flake_key}${C_RST}"
		fi

		printf '%s\n' "${_out}"
	}

	_eval_drv() {
			_expr="${1}"
			_eval_cmd="nix eval --no-warn-dirty --verbose --impure --raw ${_expr}"
			_rcfile="${MAKE_NIX_TMPDIR:-/tmp}/nix-eval.$$.rc"
			_outfile="${MAKE_NIX_TMPDIR:-/tmp}/nix-eval.$$.out"

			# Print command to stderr so it shows up immediately
			# shellcheck disable=SC2086
			print_cmd $_eval_cmd >&2

			if is_truthy "${USE_SCRIPT:-}"; then
					# Force script to run without buffering issues
					script -a -q -c "${_eval_cmd}; printf '%s\n' \$? > \"$_rcfile\"" "${_outfile}" >/dev/null
			else
					(
							eval "${_eval_cmd}"
							printf "%s\n" "$?" >"$_rcfile"
					) 2>&1 | tee "${_outfile}"
			fi

			# Remove the script header and footer
			_clean_out="$(sed -e '1d' -e '$d' "${_outfile}" | tr -d '\r')"
			# Append eval output to the running log
			#[ -n "${MAKE_NIX_LOG:-}" ] && printf "%b\n" "${_clean_out}" >> "${MAKE_NIX_LOG}"
			
			if [ "$(cat "${_rcfile}")" != "0" ]; then
					_warn="$(warn_if_dirty "${_outfile}")"
					err 1 "eval failed for ${C_CFG}${_expr}${C_RST}:\n${_clean_out}\n${_warn}"
			fi

			# Use tail -n 1 to ensure we only get the result, not the script headers.
			_drv="$(grep -o '/nix/store/[^[:space:]]*\.drv' "${_outfile}" | tail -n 1 | tr -d '\r')"

			[ -n "${_drv}" ] || err 1 "nix eval returned no derivation for ${C_CFG}${_expr}${C_RST}"
			
			# Print only the raw path to stdout for the variable assignment.
			# Any "pretty" logging about the path must go to stderr.
			logf "%b%s%b\n" "${C_PATH}" "${_drv}" "${C_RST}" >&2
			
			# This is the 'return value' captured by _out_drv="..."
			printf "%s" "${_drv}"
	}

	_has_home="$(_has_attr "homeConfigurations" "${_flake_key}")"
	_has_nixos="$(_has_attr "nixosConfigurations" "${_flake_key}")"
	_has_darwin="$(_has_attr "darwinConfigurations" "${_flake_key}")"

	if [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-home" ]; then
		if [ "${_has_home}" != "true" ]; then
			err 1 "${C_CFG}homeConfigurations.${_flake_key}${C_RST} not found in flake outputs" 
		else
			logf "\n%b<<< Checking%b %bhomeConfigurations.%s%b with command...\n" \
			"${C_INFO}" "${C_RST}" "${C_CFG}" "${_flake_key}" "${C_RST}"
			_out_drv="$(_eval_drv ".#homeConfigurations.\"${_flake_key}\".activationPackage.drvPath")"
			logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
			logf "%bOutput derivation:%b\n%b%s%b\n" "${C_INFO}" "${C_RST}" "${C_PATH}" \
				"${_out_drv}" "${C_RST}"
		fi
	fi

  if [ "${is_home_alone:-false}" = "true" ] || [ "${_checks}" = "check-home" ]; then
    return 0
  fi

  if { [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-system" ]; } && \
		[ "${is_linux}" = "true" ]; then
		if [ "${_has_nixos}" != "true" ];  then
			err 1 "${C_CFG}nixosConfigurations.${_flake_key}${C_RST} not found in flake outputs" 
		else
			logf "\n%b<<< Checking%b %bnixosConfigurations.%s%b with command...\n" \
				"${C_INFO}" "${C_RST}" "${C_CFG}" "${_flake_key}" "${C_RST}"
			_out_drv="$(_eval_drv ".#nixosConfigurations.\"${_flake_key}\".config.system.build.toplevel.drvPath")"
			logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
			logf "Output derivation: \n%b%s%b\n" "${C_PATH}" "${_out_drv}" "${C_RST}"
			return 0
		fi
  fi

  if { [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-system" ]; } && \
		[ "${is_linux}" = "false" ]; then
		if [ "${_has_darwin }" != "true" ]; then
			err 1 "${C_CFG}darwinConfigurations.${_flake_key}${C_RST} not found in flake outputs" 
		else
			logf "\n%b<<< Checking%b %b darwinConfigurations.%s%b ...\n" \
				"${C_INFO}" "${C_RST}" "${C_CFG}" "${_flake_key}" "${C_RST}"
			_out_drv="$(_eval_drv ".#darwinConfigurations.\"${_flake_key}\".system.drvPath")"
			logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
			logf "Output derivation: \n%b%s%b\n" "${C_PATH}" "${_out_drv}" "${C_RST}"
			return 0
		fi
  fi

  err 1 "No system configuration found for ${C_CFG}${_flake_key}${C_RST}"
}

# Write a configuration attribute set to pass into the Nix flake.
write_attrs() {
	_flake_key="${user}@${host}"
	
	# Attempt to load an existing configuration first
	# Modify it with any set env vars and re-write it to pass into the Nix flake.
	_rebuild="false"
	if _attrs_file="$(_find_attrs_file)"; then
		_rebuild="true"
		logf "Nix attribute file: %b%s%b\n" "${C_CFG}" "${_attrs_file}" "${C_RST}"
		_eval_vars "${_attrs_file}"
		_set_vars "rebuild" # Override attribute file with new command line vars
		_write_env
	fi

	if [ "${_rebuild}" = "false" ]; then
		# NixOS or Nix-Darwin indicate we will be using a system configuration 
		# Installing Nix-Darwin also indicates we will be using a system configuration
		if has_cmd "nix" || has_cmd "darwin-rebuild" || is_truthy "${INSTALL_DARWIN:-}"; then
			is_home_alone=false
		else
			is_home_alone=true
		fi
		_set_vars "write"
		_write_env
	fi

	logf "\n%b>>> Writing Nix configuration.%b\n" "$C_INFO" "$C_RST"
	if [ "${is_home_alone}" = "true" ]; then
		if _write_home_alone "$(resolve_path "./make-attrs/home-alone/${user}@${host}.nix")"; then
			_commit_config "${_home_alone_config}"
		else
			err 1 "Could not write configuration: ${C_CFG}${_home_alone_config}${C_RST}"
		fi
	fi

	if _write_system "$(resolve_path "./make-attrs/system/${user}@${host}.nix")"; then
		_commit_config "${_system_config}"
	else
		err 1 "Could not write configuration: ${C_CFG}${_system_config}${C_RST}"
	fi

	return 0
}

prog="${0##*/}"
mode=""

while [ $# -gt 0 ]; do
  case "${1}" in
    --check-all)   [ -z "${mode}" ] || err 2 "${prog}: duplicate mode (${mode})"; 
			mode="check-all"; shift ;;
    --check-system)   [ -z "${mode}" ] || err 2 "${prog}: duplicate mode (${mode})"; 
			mode="check-system"; shift ;;
    --check-home)   [ -z "${mode}" ] || err 2 "${prog}: duplicate mode (${mode})";
			mode="check-home"; shift ;;
    --write)   [ -z "${mode}" ] || err 2 "${prog}: duplicate mode (${mode})"; 
			mode="write"; shift ;;
    --read)   [ -z "${mode}" ] || err 2 "${prog}: duplicate mode (${mode})"; 
			mode="read"; shift ;;
    --) shift; break ;;
    -?*) err 2 "${prog}: invalid option: $1" ;;
    *) break ;;
  esac
done

[ -n "$mode" ] || err 2 "${prog}: no mode specified (use --build or --switch)"
[ $# -eq 0 ] || err 2 "${prog}: unexpected argument: $1"

case "${mode}" in
	check-all )
		check_attrs ${mode} exit $? ;;
	check-system )
		check_attrs ${mode} exit $? ;;
	check-home )
		check_attrs ${mode} exit $? ;;
	read )
		read_attrs ${mode} exit $? ;;
	write )
		write_attrs exit $? ;;
esac
