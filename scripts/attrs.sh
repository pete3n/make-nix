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
attrs_path=""
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

# Either use a hostname provided from commandline args or default to current hostname
if [ -z "${TGT_HOST:-}" ]; then
	host="$(uname -n)"
	if [ -z "${host}" ]; then
		err 1 "Could not determine local hostname"
	fi
else
	host=$TGT_HOST
fi
validate_name "host" "${host}"

# Either user a username provided from commandline args or default to the current user
if [ -z "${TGT_USER:-}" ]; then
	user="$(whoami)"
	if [ -z "$user" ]; then
		err 1 "Could not determine local user"
	fi
else
	user=$TGT_USER
fi
validate_name "user" "${user}"

# (_private): Locate a Nix attribute file for a system or home-alone configuration
# Requires: find, head
# $1: (optional) search base path - default: flake root directory
# Success:
# 	- return: 0 
# 	- stdout: absolute path to file
# Failure: 
# 	- return: 1 
# 	- stdout: ""
_find_attrs_path() {
	_base_path="${1:-}" # TODO: Configurable paths
	[ -z "${_base_path}" ] && _base_path="${flake_root}"
	_filename="${user}@${host}.nix"
	_test_path=$(find "${_base_path}" \
		-type f -name "${_filename}" 2>/dev/null | head -n 1)

	if [ -n "${_test_path}" ] && [ -r "${_test_path}" ]; then
		case "${_test_path}" in
			/*) printf "%s\n" "${_test_path}" ;;
			*)  printf "%s/%s\n" "$(pwd)" "${_test_path#./}" ;;
		esac
		return 0
	fi

	_msg="Nix attribute file ${C_PATH}${_filename}${C_RST} not found in:\n${C_PATH}"
	_msg="${_msg} ${_base_path}${C_RST} or any subdirectory."
	err 1 "${_msg}"
}

# Flag invalid configuration options
_validate_options() {
	if is_truthy "${USE_HOMEBREW:-}" && is_truthy "${IS_LINUX:-}"; then
		err 1 "Homebrew cannot be used on a Linux system. Configuration is invalid."
	fi

	return 0
}

# Update vars in env file to persist across scripts
_update_env() {
	[ -r "${MAKE_NIX_ENV}" ] || \
		err 1 "could not read environment file ${MAKE_NIX_ENV} to update it."

	_filter=""
	# Only filter out vars we have an updated value for
	[ -n "${attrs_path:-}" ] && _filter="${_filter}|ATTRS_PATH"
	[ -n "${host:-}" ] && _filter="${_filter}|TGT_HOST"
	[ -n "${user:-}" ] && _filter="${_filter}|TGT_USER"
	[ -n "${system:-}" ] && _filter="${_filter}|TGT_SYSTEM"
	[ -n "${is_linux:-}" ] && _filter="${_filter}|IS_LINUX"
	[ -n "${is_home_alone:-}" ] && _filter="${_filter}|HOME_ALONE"
	[ -n "${tags:-}" ] && _filter="${_filter}|CFG_TAGS"
	[ -n "${specs:-}" ] && _filter="${_filter}|SPECS"
	[ -n "${use_homebrew:-}" ] && _filter="${_filter}|USE_HOMEBREW"
	[ -n "${use_cache:-}" ] && _filter="${_filter}|USE_CACHE"
	[ -n "${use_keys:-}" ] && _filter="${_filter}|USE_KEYS"

	if [ -n "$_filter" ]; then
		_filter="^(${_filter#|})="
		_other_vars=$(grep -vE "$_filter" "${MAKE_NIX_ENV}" || :; printf "x")
	else
		# If no new vars are set, just read the whole file
		_other_vars=$(cat "${MAKE_NIX_ENV}"; printf "x")
	fi
	_other_vars=${_other_vars%x}

	{
		printf "%s" "${_other_vars}"

		# Only update values that are set
		[ -n "${attrs_path:-}" ] && printf "ATTRS_PATH=%s\n" "${attrs_path}"
		[ -n "${host:-}" ] && printf "TGT_HOST=%s\n" "${host}"
		[ -n "${user:-}" ] && printf "TGT_USER=%s\n" "${user}"
		[ -n "${system:-}" ] && printf "TGT_SYSTEM=%s\n" "${system}"
		[ -n "${is_linux:-}" ] && printf "IS_LINUX=%s\n" "${is_linux}"
		[ -n "${is_home_alone:-}" ] && printf "HOME_ALONE=%s\n" "${is_home_alone}"
		[ -n "${tags:-}" ] && printf "CFG_TAGS=%s\n" "${tags}"
		[ -n "${specs:-}" ] && printf "SPECS=%s\n" "${specs}"
		[ -n "${use_homebrew:-}" ] && printf "USE_HOMEBREW=%s\n" "${use_homebrew}"
		[ -n "${use_cache:-}" ] && printf "USE_CACHE=%s\n" "${use_cache}"
		[ -n "${use_keys:-}" ] && printf "USE_KEYS=%s\n" "${use_keys}"
	} > "${MAKE_NIX_ENV}"
}

# Set global configuration vars based on env variables or autodetected defaults
# Write defaults and autodetected values to new files, otherwise only update 
# New user provided values.
_set_vars() {
	_is_new_file="${1}"

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
  if [ "${_is_new_file}" = "true" ] && [ -z "${HOME_ALONE-}" ]; then
    : "${is_home_alone:=false}"
  fi

	# Use Homebrew for packages in Nix Darwin configuration
  _assign_bool_if_set USE_HOMEBREW use_homebrew
  if [ "${_is_new_file}" = "true" ] && [ -z "${USE_HOMEBREW-}" ]; then
    : "${use_homebrew:=false}"
  fi

	# Use Cache server values defined in hosts/infrax.nix for Nixos configurations
	# and in make.env for Nix-Darwin and Home-alone configurations
  _assign_bool_if_set USE_CACHE use_cache
  if [ "${_is_new_file}" = "true" ] && [ -z "${USE_CACHE-}" ]; then
    : "${use_cache:=false}"
  fi

	# Use trusted key values defined in hosts/infrax.nix for Nixos configurations
	# and in make.env for Nix-Darwin and Home-alone configurations
  _assign_bool_if_set USE_KEYS use_keys
  if [ "${_is_new_file}" = "true" ] && [ -z "${USE_KEYS-}" ]; then
    : "${use_keys:=false}" 
  fi

	# Tags to pass to the Nix configuration to customize at build time
	if [ "${CFG_TAGS+x}" ]; then
		tags="${CFG_TAGS}"
	elif [ "${_is_new_file}" = "true" ]; then
		tags=""
	fi

	# Boot specialisations to build for the system configuration
	if [ "${SPECS+x}" ]; then
		specs="${SPECS}"
	elif [ "${_is_new_file}" = "true" ]; then
		specs=""
	fi

	# Target system tuple, autodetect and use host system if none provided
	# Don't override the system if checking or rebuilding an attribute set
  if [ -n "${TGT_SYSTEM-}" ]; then
    system="${TGT_SYSTEM}"
  elif [ "${_is_new_file}" = "true" ]; then
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

# (Private): Assign global configuration values be evaluating an attribute file using Nix
# Requires: nix, nix-instantiate
# $1: Nix attribute filepath to evaluate
# Succes:
# 	- return: 0
_eval_vars() {
	_attrs_path="${1}"
	_base_expr="let attr = import \"${_attrs_path}\" {}; in attr"

	# nix-instantiate is required to parse the attribute file for syntax errors
  if ! has_cmd "nix-instantiate"; then
		# Attempt to fix PATH issues
    source_nix
  fi

  if ! has_cmd "nix-instantiate"; then
    err 1 "nix-instantiate not found. Cannot validate Nix syntax"
  fi

  if ! _out=$(nix-instantiate --parse "$_attrs_path" 2>&1); then
    err 1 "Invalid attrs file ${C_PATH}${_attrs_path}${C_RST}:\n${_out}"
  fi

	_nix_eval() {
		_expr="${1}"

		if ! _out=$(
			NIX_CONFIG='extra-experimental-features = nix-command flakes' \
			command nix eval --raw --impure --expr "${_expr}" 2>&1
		); then
			_msg="nix eval failed while reading attrs file"
			_msg="${_msg} ${C_PATH}${_attrs_path}${C_RST}:\n${_out}\nexpr:\n${_expr}"
			err 1 "${_msg}"
		fi
		printf "%s" "${_out}"
	}

  _user="$(_nix_eval "${_base_expr}.user or \"\"")"
	if [ "${_user}" !=  "${user}" ]; then
		err 1 "The user specified in the attribute file: ${C_CFG}${_user}${C_RST} " \
					"does not match the target user: ${C_CFG}${user}${C_RST}"
	fi
  _host="$(_nix_eval "${_base_expr}.host or \"\"")"
	if [ "${_host}" != "${host}" ]; then
		err 1 "The host specified in the attribute file: ${C_CFG}${_host}${C_RST} " \
					"does not match the target host: ${C_CFG}${host}${C_RST}"
	fi
  system="$(_nix_eval "${_base_expr}.system or \"\"")"

	is_home_alone="$(_nix_eval "builtins.toString (${_base_expr}.isHomeAlone or false)")"
	is_home_alone="$(normalize_bool "${is_home_alone}")"
	is_linux="$(_nix_eval "builtins.toString (${_base_expr}.isLinux or false)")"
	is_linux="$(normalize_bool "${is_linux}")"
	use_homebrew="$(_nix_eval "builtins.toString (${_base_expr}.useHomebrew or false)")"
	use_homebrew="$(normalize_bool "${use_homebrew}")"
	use_keys="$(_nix_eval "builtins.toString (${_base_expr}.useKeys or false)")"
	use_keys="$(normalize_bool "${use_keys}")"
	use_cache="$(_nix_eval "builtins.toString (${_base_expr}.useCache or false)")"
	use_cache="$(normalize_bool "${use_cache}")"

  tags="$(_nix_eval "builtins.concatStringsSep \",\" (${_base_expr}.tags or [])")"
  specs="$(_nix_eval "builtins.concatStringsSep \",\" (${_base_expr}.specialisations or [])")"

	_msg="\n${C_INFO}<<< Reading attributes:${C_RST}\n"
	_msg="${_msg} user: %b%s%b\n host: %b%s%b\n system: %b%s%b\n"
	_msg="${_msg} is_linux: %b%s%b\n is_home_alone: %b%s%b\n use_homebrew: %b%s%b\n"
	_msg="${_msg} use_keys: %b%s%b\n use_cache: %b%s%b\n"
	_msg="${_msg} tags: %b%s%b\n specs: %b%s%b\n"

	logf "$_msg" \
		"${C_CFG}" "${user}" "${C_RST}" "${C_CFG}" "${host}" "${C_RST}"\
		"${C_CFG}" "${system}" "${C_RST}" "${C_CFG}" "${is_linux}" "${C_RST}"\
		"${C_CFG}" "${is_home_alone}" "${C_RST}" "${C_CFG}" "${use_homebrew}" "${C_RST}"\
		"${C_CFG}" "${use_keys}" "${C_RST}" "${C_CFG}" "${use_cache}" "${C_RST}"\
		"${C_CFG}" "${tags}" "${C_RST}" "${C_CFG}" "${specs}" "${C_RST}"
}

# Read the Nix attribute file and update the env vars
read_attrs() {
	_attrset="${1:-${user}@${host}}"

	# Don't attempt to update the env path to the attr file if it is already set
	if [ -z "${ATTRS_PATH:-}" ]; then
		attrs_path="$(_find_attrs_path)" || : # Don't exit on error
	else
		attrs_path="${ATTRS_PATH}"
	fi
	
	if [ -r "${attrs_path}" ]; then
		logf "\n%b✅ Found Nix attribute file:%b\n%b%s%b\n" "${C_OK}" "${C_RST}" \
			"${C_PATH}" "${attrs_path}" "${C_RST}"
	else
		logf "\n"
		_msg="Failed to read Nix attributes.\nNo attrs file was found for: "
		_msg="${_msg}${C_CFG}${_attrset}${C_RST}"
		err 1 "${_msg}"
	fi

	_eval_vars "${attrs_path}"
	_update_env
}

# Load a configuration attribute set based on user and host names. 
# Evaluate the configuration using Nix eval as appropriate for the configuraiton type.
check_attrs() {
	_checks="${1}"
	_rc=""
	_drv_attrset=""
	_out_drv=""
	_attrset="${user}@${host}"

	read_attrs "${_attrset}"

	# Determine if flake has an attribute; returns "true" or "false"
	_has_attr() {
		_output="${1}"	# homeConfigurations | nixosConfigurations | darwinConfigurations
		_attrset="${2:-${user}@${host}}"
		_flake_path="path:${flake_root}"

		if ! _out="$(
			NIX_CONFIG='extra-experimental-features = nix-command flakes' \
			command nix eval --impure --json \
				"${_flake_path}#${_output}" \
				--apply "config: builtins.hasAttr \"${_attrset}\" config"
		)"; then
			err 1 "nix eval failed while checking ${C_CFG}${_output}.${_attrset}${C_RST}"
		fi

		printf '%s\n' "${_out}"
	}
	_has_home="$(_has_attr "homeConfigurations" "${_attrset}")"
	_has_nixos="$(_has_attr "nixosConfigurations" "${_attrset}")"
	_has_darwin="$(_has_attr "darwinConfigurations" "${_attrset}")"

	_eval_drv_bak() {
		_expr="${1}"
		_eval_cmd="nix eval --no-warn-dirty --impure --raw ${_expr}"
		_rcfile="${MAKE_NIX_TMPDIR:-/tmp}/nix-eval.$$.rc"
		_outfile="${MAKE_NIX_TMPDIR:-/tmp}/nix-eval.$$.out"

		# Print command to stderr so it shows up immediately
		# shellcheck disable=SC2086
		print_cmd $_eval_cmd >&2

		if is_truthy "${USE_SCRIPT:-}"; then
			# Force script to run without buffering issues
			script -a -q -c "${_eval_cmd}; printf '%s\n' \$? > \"$_rcfile\"" "${_outfile}" >/dev/null
			# Remove the script header and footer
			_clean_out="$(sed -e '1d' -e '$d' "${_outfile}" | tr -d '\r')"
		else
			(
				eval "${_eval_cmd}"
				printf "%s\n" "$?" >"$_rcfile"
			) 2>&1 | tee "${_outfile}"
			_clean_out="${_outfile}"
		fi

		printf "\nDEBUG RC file: %s\n" "${_rcfile}"
		if [ "$(cat "${_rcfile}")" != "0" ]; then
				printf "\nDEBUG RC not 0\n"
				_warn="$(warn_if_dirty "${_outfile}")"
				err 1 "eval failed for ${C_CFG}${_expr}${C_RST}:\n${_clean_out}\n${_warn}"
		fi

		# Use tail -n 1 to ensure we only get the result, not the script headers.
		_drv="$(grep -o '/nix/store/[^[:space:]]*\.drv' "${_clean_out}" | tail -n 1 | tr -d '\r')"

		[ -n "${_drv}" ] || err 1 "nix eval returned no derivation for ${C_CFG}${_expr}${C_RST}"
		printf "%s" "${_drv}"
	}


_eval_drv() {
  _expr=$1

  _tmpdir="${MAKE_NIX_TMPDIR:-/tmp}"
  _rcfile="$_tmpdir/nix-eval.$$.rc"
  _outfile="$_tmpdir/nix-eval.$$.out"
  _cleanfile="$_tmpdir/nix-eval.$$.clean"

  _outfifo="$_tmpdir/nix-eval.$$.out.fifo"
  _errfifo="$_tmpdir/nix-eval.$$.err.fifo"

  print_cmd nix eval --no-warn-dirty --impure --raw "$_expr" >&2

  rm -f "$_rcfile" "$_outfile" "$_cleanfile" "$_outfifo" "$_errfifo"
  mkfifo "$_outfifo" "$_errfifo" || err 1 "failed to create FIFOs"

  # Tee stdout → terminal + logfile
  tee "$_outfile" <"$_outfifo" &
  _out_pid=$!

  # Tee stderr → terminal(stderr) + logfile
  tee -a "$_outfile" <"$_errfifo" >&2 &
  _err_pid=$!

  # Run nix eval with stdout/stderr redirected to FIFOs
  nix eval --no-warn-dirty --impure --raw "$_expr" \
    >"$_outfifo" 2>"$_errfifo"
  _rc=$?

  printf "%s\n" "$_rc" >"$_rcfile"

  # Close FIFOs so tee exits cleanly
  rm -f "$_outfifo" "$_errfifo"
  wait "$_out_pid" 2>/dev/null
  wait "$_err_pid" 2>/dev/null

  # Normalized clean output (strip CR just in case)
  tr -d '\r' <"$_outfile" >"$_cleanfile"

  if [ "$_rc" != 0 ]; then
    _warn="$(warn_if_dirty "$_outfile")"
    err 1 "eval failed for ${C_CFG}${_expr}${C_RST}:\n$(cat "$_cleanfile")\n${_warn}"
  fi

  _drv="$(grep -o '/nix/store/[^[:space:]]*\.drv' "$_cleanfile" | tail -n 1)"
  [ -n "$_drv" ] || err 1 "nix eval returned no derivation for ${C_CFG}${_expr}${C_RST}"
}

	if [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-home" ]; then
		if [ "${_has_home}" != "true" ]; then
			err 1 "${C_CFG}homeConfigurations.${_attrset}${C_RST} not found in flake outputs" 
		else
			_drv_attrset="activationPackage.drvPath"
			logf "\n%b<<< Checking%b %bhomeConfigurations.%s%b with command...\n" \
			"${C_INFO}" "${C_RST}" "${C_CFG}" "${_attrset}" "${C_RST}"
			if _out_drv="$(_eval_drv "${flake_root}#homeConfigurations.\"${_attrset}\".${_drv_attrset}")"; then
				logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
				logf "%b>>> Output derivation:%b\n%b%s%b\n" "${C_INFO}" "${C_RST}" "${C_PATH}" \
					"${_out_drv}" "${C_RST}"
			fi
		fi
	fi

	# Return early if not checking system configurations
  if [ "${is_home_alone:-"false"}" = "true" ] || [ "${_checks}" = "check-home" ]; then
    return 0
  fi

  if { [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-system" ]; } && \
		[ "${is_linux}" = "true" ]; then
		if [ "${_has_nixos}" != "true" ];  then
			err 1 "${C_CFG}nixosConfigurations.${_attrset}${C_RST} not found in flake outputs" 
		else
			_drv_attrset="config.system.build.toplevel.drvPath"
			logf "\n%b<<< Checking%b %bnixosConfigurations.%s%b with command...\n" \
				"${C_INFO}" "${C_RST}" "${C_CFG}" "${_attrset}" "${C_RST}"
			if _out_drv="$(_eval_drv "${flake_root}#nixosConfigurations.\"${_attrset}\".${_drv_attrset}")"; then
				logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
				logf "%b>>> Output derivation:%b\n%b%s%b\n" "${C_INFO}" "${C_RST}" "${C_PATH}" \
					"${_out_drv}" "${C_RST}"
				return 0 
			fi
		fi
  fi

  if { [ "${_checks}" = "check-all" ] || [ "${_checks}" = "check-system" ]; } && \
		[ "${is_linux}" = "false" ]; then
		if [ "${_has_darwin}" != "true" ]; then
			err 1 "${C_CFG}darwinConfigurations.${_attrset}${C_RST} not found in flake outputs" 
		else
			_drv_attrset="system.drvPath"
			logf "\n%b<<< Checking%b %b darwinConfigurations.%s%b ...\n" \
				"${C_INFO}" "${C_RST}" "${C_CFG}" "${_attrset}" "${C_RST}"
			if _out_drv="$(_eval_drv "${flake_root}#darwinConfigurations.\"${_attrset}\".${_drv_attrset}")"; then
				logf "\n%b✅ eval passed.%b\n" "${C_OK}" "${C_RST}"
				logf "%b>>> Output derivation:%b\n%b%s%b\n" "${C_INFO}" "${C_RST}" "${_out_drv}" "${C_PATH}"
				return 0
			fi
		fi
  fi

  err 1 "No system configuration found for ${C_CFG}${_attrset}${C_RST}"
}

# Write a configuration attribute set to pass into the Nix flake.
write_attrs() {
	_attrset="${user}@${host}"
	_is_new_file=""
	_attrs_path=""

	_print_new_attrs() {
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
				set -f; _old_ifs=$IFS; IFS=','
				for _tag in $tags; do printf ' "%s"' "${_tag}"; done # FIXED: printf
				IFS="${_old_ifs}"; set +f
		fi
		printf " ];\n"
		printf "  specialisations = ["
		if [ -n "${specs}" ]; then
				_old_ifs=$IFS; IFS=','
				for _spec in $specs; do printf ' "%s"' "${_spec}"; done # FIXED: printf
				IFS="${_old_ifs}"
		fi
		printf " ];\n"
		printf '}\n'
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

		logf "%b>>> Committing%b %b%s%b to git tree.\n" \
			"${C_INFO}" "${C_RST}" "${C_PATH}" "${_filename}" "${C_RST}"

		GIT_AUTHOR_NAME="make-nix" \
		GIT_AUTHOR_EMAIL="make-nix@bot" \
		GIT_COMMITTER_NAME="make-nix" \
		GIT_COMMITTER_EMAIL="make-nix@bot" \
		git commit -m "build: Make-nix automated commit to keep git tree clean"
	}

	_write_new_attrs() {
		_attr_path="${1}"

		logf "\n%b>>> Writing%b %b%s%b with:\n" \
			"${C_INFO}" "${C_RST}" "${C_PATH}" "${_attr_path}" "${C_RST}"
		logf "{ ... }:\n{\n"
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
		logf '}\n'

		_print_new_attrs >"${_attr_path}"
	}

	_update_attrs() {
		_attr_path="${1}"
		_modified=""

		logf "\n%b<<< Checking Nix configuration for changes.%b\n" "$C_INFO" "$C_RST"
		if is_modified "${_attr_path}" "$(_print_new_attrs)"; then
			_modified="true"
			_write_new_attrs "${_attr_path}" || err 1 "Error writing attribute changes.\n"
		else
			logf "\n%bNo changes found.%b\n" "$C_INFO" "$C_RST"
			return 0
		fi
	}

	# Attempt to load an existing configuration first
	# Modify it with any set env vars and re-write it to pass into the Nix flake.
	if [ -z "${attrs_path:-}" ]; then
		_attrs_path="$(_find_attrs_path)" || :
		attrs_path="${_attrs_path}"
	fi
		
	if [ -n "${attrs_path:-}" ] && [ -r "${attrs_path}" ]; then
		logf "\n%b✅ Found Nix attribute file:%b\n%b%s%b\n" "${C_OK}" "${C_RST}" \
			"${C_PATH}" "${attrs_path}" "${C_RST}"
		_eval_vars "${attrs_path}"
		_set_vars "false"
		_update_env
		_is_new_file="false"
	else
		_set_vars "true"
		_update_env
		_is_new_file="true"
	fi
	
	if [ "${_is_new_file}" = "true" ] && [ "${is_home_alone}" = "true" ]; then
		_target_path="$(resolve_path "./make-attrs/home-alone/${_attrset}.nix")"
		logf "New Nix attribute file will be written: %b%s%b\n" "${C_PATH}" "${_target_path}" "${C_RST}"
		_write_new_attrs "${_target_path}" "home-alone" || \
			err 1 "Could not generate configuration: ${C_PATH}${_target_path}${C_RST}"
		_commit_config "${_target_path}";
	fi

	if [ "${_is_new_file}" = "true" ] && [ "${is_home_alone}" = "false" ]; then
		_target_path="$(resolve_path "./make-attrs/system/${_attrset}.nix")"
		logf "New Nix attribute file will be written: %b%s%b\n" "${C_PATH}" "${_target_path}" "${C_RST}"
		_write_new_attrs "${_target_path}" "system" || \
			err 1 "Could not generate configuration: ${C_PATH}${_target_path}${C_RST}"
		_commit_config "${_target_path}";
	fi

	if [ "${_is_new_file}" = "false" ] && [ "${is_home_alone}" = "true" ]; then
		_update_attrs "${attrs_path}" "home-alone" || \
			err 1 "Could not update configuration: ${C_PATH}${attrs_path}${C_RST}"
		_commit_config "${attrs_path}";
	fi

	if [ "${_is_new_file}" = "false" ] && [ "${is_home_alone}" = "false" ]; then
		_update_attrs "${attrs_path}" "system" || \
			err 1 "Could not update configuration: ${C_PATH}${attrs_path}${C_RST}"
		_commit_config "${attrs_path}";
	fi
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
