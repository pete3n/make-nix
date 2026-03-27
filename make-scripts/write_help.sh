#!/usr/bin/env sh
set -eu

[ "${NO_ANSI:-}" ] && BOLD='' || BOLD='\033[1m'
[ "${NO_ANSI:-}" ] && BLUE='' || BLUE='\033[1;34m'
[ "${NO_ANSI:-}" ] && CYAN='' || CYAN='\033[1;36m'
[ "${NO_ANSI:-}" ] && GREEN='' || GREEN='\033[1;32m'
[ "${NO_ANSI:-}" ] && MAGENTA='' || MAGENTA='\033[0;35m'
[ "${NO_ANSI:-}" ]  && RED='' || RED='\033[0;31m'
#[ "${NO_ANSI:-}" ]  && YELLOW='' || YELLOW='\033[1;33m'
[ "${NO_ANSI:-}" ]  && RESET='' || RESET='\033[0m'
C_CMD="${BOLD}"
C_CFG="${CYAN}"
C_ERR="${RED}"
C_INFO="${BLUE}"
C_OK="${GREEN}"
C_PATH="${MAGENTA}"
C_RST="${RESET}"
#C_WARN="${YELLOW}"

if [ -n "${NO_ANSI+x}" ]; then
    # shellcheck disable=SC1091
    . "$(dirname "$0")/no_ansi.env"
    help_file="$(dirname "$0")/help_no_ansi.txt"
else
    # shellcheck disable=SC1091
    . "$(dirname "$0")/ansi.env"
    help_file="$(dirname "$0")/help.txt"
fi

: > "$help_file"

write_line() {
    printf "%b\n" "$1" >> "$help_file"
}

write_line "make-nix help\n"
write_line "Usage:"
write_line "${C_ERR}make${C_RST} ${C_CMD}<help|install|check|build|switch|all>${C_RST}\n\
[${C_CFG}TGT_USER${C_RST}${C_ERR}=${C_RST}<user>]\n\
[${C_CFG}TGT_HOST${C_RST}${C_ERR}=${C_RST}<host>]\n\
[${C_CFG}TGT_SYSTEM${C_RST}${C_ERR}=${C_RST}<system>]\n\
[${C_CFG}CFG_TAGS${C_RST}${C_ERR}=${C_RST}<tag1>${C_ERR},${C_RST}<tag2>${C_ERR},${C_RST}...]\n\
[${C_CFG}SPECS${C_RST}${C_ERR}=${C_RST}<spc1>${C_ERR},${C_RST}<spc2>${C_ERR},${C_RST}...]\n\
[${C_INFO}OPTION FLAGS${C_RST}]\n"

write_line "${C_CMD}Make targets:${C_RST}"
write_line "  ${C_CMD}help${C_RST}    - You are here."
write_line "  ${C_CMD}install${C_RST} - Install Nix and/or Nix-Darwin on a bare MacOS or Linux system."
write_line "           Will not execute on NixOS or Nix-Darwin managed systems."
write_line "  ${C_CMD}uninstall${C_RST} - Uninstall Nix and/or Nix-Darwin on a bare MacOS or Linux system."
write_line "           Will not execute on NixOS or Nix-Darwin managed systems."
write_line "  ${C_CMD}check${C_RST}   - Validate flake configurations for the target user and host."
write_line "           Sub-targets: ${C_CMD}check-home${C_RST}, ${C_CMD}check-system${C_RST}"
write_line "  ${C_CMD}build${C_RST}   - Build Nix closures for home and system configurations."
write_line "           Runs check first to prevent configuration mismatches."
write_line "           Sub-targets: ${C_CMD}build-home${C_RST}, ${C_CMD}build-system${C_RST}"
write_line "  ${C_CMD}switch${C_RST}  - Check, build, and activate configurations."
write_line "           Sub-targets: ${C_CMD}switch-home${C_RST}, ${C_CMD}switch-system${C_RST}"
write_line "  ${C_CMD}all${C_RST}     - Full pipeline: install through switch for a bare system.\n"

write_line "${C_CFG}Configuration parameters${C_RST} (autodetected from current system if not set):"
write_line "  ${C_CFG}TGT_USER${C_RST}    - Target username. Defaults to current user."
write_line "             Override to build a configuration for a different user."
write_line "  ${C_CFG}TGT_HOST${C_RST}    - Target hostname. Defaults to current hostname."
write_line "             Override to build a configuration for a different host."
write_line "  ${C_CFG}TGT_SYSTEM${C_RST}  - Target system tuple. Defaults to current platform."
write_line "             Valid values: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin."
write_line "             Override to cross-build for a different architecture."
write_line "  ${C_CFG}CFG_TAGS${C_RST}    - Comma-separated tags to customise the Home Manager configuration"
write_line "             at build time (no spaces). Example: ${C_CFG}CFG_TAGS${C_RST}${C_ERR}=${C_RST}server,minimal"
write_line "  ${C_CFG}SPECS${C_RST}       - Comma-separated list of NixOS specialisation configurations"
write_line "             to build (no spaces). Example: ${C_CFG}SPECS${C_RST}${C_ERR}=${C_RST}egpu,powersave\n"
write_line "  Configuration is stored in ${C_PATH}make-attrs/system/<user>@<host>.nix${C_RST} or"
write_line "  ${C_PATH}make-attrs/home-alone/<user>@<host>.nix${C_RST} and committed to git automatically."
write_line "  On subsequent runs, existing attribute files are read and updated with any new values.\n"

write_line "${C_INFO}Option flags${C_RST} (boolean — assign any truthy value to enable):"
write_line "Truthy values: 1 y Y yes Yes YES on On ON true True TRUE"
write_line "Falsey values: 0 n N no No NO off Off OFF false False FALSE\n"

write_line "Install flags (${C_CMD}install${C_RST}${C_ERR}|${C_RST}${C_CMD}all${C_RST}):"
write_line "  ${C_INFO}USE_DETERMINATE${C_RST}${C_ERR}=${C_RST}true  - Install Nix using the Determinate Systems installer."
write_line "                         Default installer is the official NixOS installer.\n"
write_line "  ${C_INFO}INSTALL_DARWIN${C_RST}${C_ERR}=${C_RST}true   - Install Nix-Darwin for MacOS.\n"
write_line "  ${C_INFO}USE_HOMEBREW${C_RST}${C_ERR}=${C_RST}true     - Install Homebrew (MacOS only).\n"
write_line "  ${C_INFO}SINGLE_USER${C_RST}${C_ERR}=${C_RST}true      - Install Nix in single-user mode."
write_line "                         Only supported with the default installer.\n"
write_line "  ${C_INFO}USE_CACHE${C_RST}${C_ERR}=${C_RST}true        - Use additional binary cache substituters defined in"
write_line "                         ${C_PATH}make.env${C_RST} as ${C_CFG}NIX_CACHE_URLS${C_RST} (comma-separated, no spaces).\n"
write_line "  ${C_INFO}USE_KEYS${C_RST}${C_ERR}=${C_RST}true         - Trust additional public keys defined in"
write_line "                         ${C_PATH}make.env${C_RST} as ${C_CFG}TRUSTED_PUBLIC_KEYS${C_RST} (comma-separated).\n"

write_line "Configuration flags (${C_CMD}check${C_RST}${C_ERR}|${C_RST}${C_CMD}build${C_RST}${C_ERR}|${C_RST}${C_CMD}switch${C_RST}${C_ERR}|${C_RST}${C_CMD}all${C_RST}):"
write_line "  ${C_INFO}DRY_RUN${C_RST}${C_ERR}=${C_RST}true          - Evaluate the configuration without building or activating it."
write_line "                         Passes --dry-run to Nix. No outputs will be produced.\n"
write_line "  ${C_INFO}HOME_ALONE${C_RST}${C_ERR}=${C_RST}true       - Configure for a system running Home Manager without"
write_line "                         NixOS or Nix-Darwin. Autodetected if not set.\n"
write_line "  ${C_INFO}USE_HOMEBREW${C_RST}${C_ERR}=${C_RST}true     - Enable Homebrew package options in a Nix-Darwin configuration.\n"
write_line "  ${C_INFO}USE_CACHE${C_RST}${C_ERR}=${C_RST}true        - Use additional binary cache substituters (see above).\n"
write_line "  ${C_INFO}USE_KEYS${C_RST}${C_ERR}=${C_RST}true         - Trust additional public keys (see above).\n"

write_line "Universal flags (any target):"
write_line "  ${C_INFO}KEEP_LOGS${C_RST}${C_ERR}=${C_RST}true        - Preserve logs after operations instead of cleaning up."
write_line "                         Useful for debugging. Log paths are printed at startup.\n"

write_line "Usage examples:"

write_line "  ${C_OK}- Install Nix using the default installer in single-user mode:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}install${C_RST} ${C_INFO}SINGLE_USER${C_RST}${C_ERR}=${C_RST}true\n"

write_line "  ${C_OK}- Install Nix using the Determinate Systems installer and Nix-Darwin on MacOS:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}install${C_RST} ${C_INFO}USE_DETERMINATE${C_RST}${C_ERR}=${C_RST}true ${C_INFO}INSTALL_DARWIN${C_RST}${C_ERR}=${C_RST}true\n"

write_line "  ${C_OK}- Validate flake configurations for the current user and host:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}check${C_RST}\n"

write_line "  ${C_OK}- Validate only the home-manager configuration for the current user:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}check-home${C_RST}\n"

write_line "  ${C_OK}- Build and activate the Home Manager configuration for the current user${C_RST}"
write_line "  ${C_OK}  on a standalone system (no NixOS or Nix-Darwin):${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}switch-home${C_RST} ${C_INFO}HOME_ALONE${C_RST}${C_ERR}=${C_RST}true\n"

write_line "  ${C_OK}- Build and activate the current system configuration; autodetect all settings:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}switch-system${C_RST}\n"

write_line "  ${C_OK}- Build and activate the Home Manager configuration for user sam on host xps-15,${C_RST}"
write_line "  ${C_OK}  with tags 'debian' and 'server', targeting aarch64-linux:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}switch-home${C_RST} ${C_CFG}TGT_USER${C_RST}${C_ERR}=${C_RST}sam ${C_CFG}TGT_HOST${C_RST}${C_ERR}=${C_RST}xps-15 \\"
write_line "      ${C_CFG}TGT_SYSTEM${C_RST}${C_ERR}=${C_RST}aarch64-linux ${C_CFG}CFG_TAGS${C_RST}${C_ERR}=${C_RST}debian,server ${C_INFO}HOME_ALONE${C_RST}${C_ERR}=${C_RST}true\n"

write_line "  ${C_OK}- Dry-run evaluation of both system and home configurations; autodetect all settings:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}switch${C_RST} ${C_INFO}DRY_RUN${C_RST}${C_ERR}=${C_RST}true\n"

write_line "  ${C_OK}- Full bootstrap of a bare system: install Nix and activate all configurations:${C_RST}"
write_line "    ${C_ERR}make${C_RST} ${C_CMD}all${C_RST}\n"
