#!/usr/bin/env sh
set -eu

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
write_line "${RED}make${RESET} ${BOLD}<help|install|home|system|all|test>${RESET}\n\
[${CYAN}TGT_USER${RESET}${RED}=${RESET}<user>]\n\
[${CYAN}TGT_HOST${RESET}${RED}=${RESET}<host>]\n\
[${CYAN}TGT_TAGS${RESET}${RED}=${RESET}<tag1>${RED},${RESET}<tag2>${RED},${RESET}<tag3>${RED},${RESET}...]\n\
[${CYAN}TGT_SYSTEM${RESET}${RED}=${RESET}<system>]\n\
[${CYAN}TGT_SPEC${RESET}${RED}=${RESET}<spc1>${RED},${RESET}<spc2>${RED},${RESET}<spc3>${RED},${RESET}...]\n\
[${BLUE}OPTION FLAGS${RESET}]\n"

write_line "${BOLD}Make targets:${RESET}"
write_line "  ${BOLD}help${RESET}    - You are here."
write_line "  ${BOLD}install${RESET} - Install Nix and/or Nix-Darwin. Will not execute on NixOS or Nix-Darwin systems."
write_line "  ${BOLD}home${RESET}    - Build and activate a Home-manager configuration."
write_line "  ${BOLD}system${RESET}  - Build and activate a NixOS or Nix-Darwin system configuration."
write_line "  ${BOLD}all${RESET}     - Execute both the system and home targets in that order."
write_line "  ${BOLD}test${RESET}    - Check all flake configurations.\n"

write_line "${CYAN}Configuration parameters:${RESET}"
write_line "  ${CYAN}TGT_USER${RESET}    - User configuration (current user will be passed by default)."
write_line "  ${CYAN}TGT_HOST${RESET}    - System configuration host (current hostname will be passed by default)."
write_line "  ${CYAN}TGT_TAGS${RESET}    - User allows to customizing home-manager user configuration based on tags similar to specialisations for system configurations."
write_line "  ${CYAN}TGT_SYSTEM${RESET}  - System platform to target for builds: x86_64-linux, aarch64-linux, x86_64-darwin, or aarch64-darwin (current platform will be passed by default.)"
write_line "  ${CYAN}TGT_SPEC${RESET}    - Comma separated list of NixOS system specialisation configurations (no spaces).\n"

write_line "${BLUE}Option flags${RESET} (These are boolean, assigning ${BOLD}any truthy${RESET} value will enable them):"
write_line "Truthy values are 1 yes Yes YES true True TRUE on On ON y Y\n"
write_line "Install option flags (install):"
write_line "  ${BLUE}DETERMINATE${RESET}${RED}=${RESET}true  - Install Nix using the Determinate Systems installer.\n"
write_line "  ${BLUE}NIX_DARWIN${RESET}${RED}=${RESET}true   - Install Nix-Darwin for MacOS.\n"
write_line "  ${BLUE}USE_HOMEBREW${RESET}${RED}=${RESET}true - Install Homebrew.\n"
write_line "  ${BLUE}SINGLE_USER${RESET}${RED}=${RESET}true  - Install Nix for single-user mode (default installer only).\n"
write_line "  ${BLUE}USE_CACHE${RESET}${RED}=${RESET}true    - Set a additional cache server URLs to be used as substituters (cache.nixos.org is used by default). This option is defined in make.env as a comma separated list of URLs (no spaces) in order of precedence.\n"
write_line "  ${BLUE}USE_KEYS${RESET}${RED}=${RESET}true     - Set additional trusted public keys for nix stores (cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= is used by default). This option is defined in make.env as comma separated list of Nix keyname:keyvalue pairs.\n"

write_line "Configuration option flags (home|system|all):"
write_line "  ${BLUE}DRY_RUN${RESET}${RED}=${RESET}true      - Evaluate the new configuration but don't activate it.\n"
write_line "  ${BLUE}USE_HOMEBREW${RESET}${RED}=${RESET}true - Configure Homebrew package options for Nix-Darwin configurations.\n"
write_line "  ${BLUE}HOME_ALONE${RESET}${RED}=${RESET}true   - Configure options for a system running home-manager without NixOS or Nix-Darwin (autodetects current system).\n"
write_line "  ${BLUE}BOOT_SPEC${RESET}${RED}=${RESET}true    - Set the default boot menu option to the ${BOLD}first${RESET} listed specialisation. (NOTE: Only supports systemd boot configurations.)\n"

write_line "Additional option flags (any target):"
write_line "  ${BLUE}KEEP_LOGS${RESET}${RED}=${RESET}true    - Don't erase logs after operations (for debugging).\n"

write_line "Usage examples:"

write_line "  ${GREEN}- Install Nix using the default installer for single-user mode:"
write_line "    ${RED}make${RESET} ${BOLD}install${RESET} ${BLUE}SINGLE_USER${RESET}${RED}=${RESET}Y\n"

write_line "  ${GREEN}- Install Nix-Darwin using the Determinate Systems installer:"
write_line "    ${RED}make${RESET} ${BOLD}install${RESET} ${BLUE}DETERMINATE${RESET}${RED}=${RESET}1 ${BLUE}NIX_DARWIN${RESET}${RED}=${RESET}y\n"

write_line "  ${GREEN}- Build and activate the home-manager configuration for the current user using a standalone home-manager configuration; autodetect hostname and system type:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${BLUE}HOME_ALONE${RESET}${RED}=${RESET}true\n"

write_line "  ${GREEN}- Build and activate the current system's configuration; autodetect hostname and system platform:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}system${RESET}\n"

write_line "  ${GREEN}- Build and activate the standalone home-manager configuration for user sam on host xps-15, set the tags 'debian' and 'server', and build for an aarch64-linux platform:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${CYAN}user${RESET}${RED}=${RESET}sam ${CYAN}host${RESET}${RED}=${RESET}xps-15 \
${CYAN}system${RESET}${RED}=${RESET}aarch64-linux ${BLUE}HOME_ALONE${RESET}${RED}=${RESET}1 ${CYAN}tags${RESET}${RED}=${RESET}debian,server\n"

write_line "  ${GREEN}- Rebuild and switch the system configuration for host workstation1; autodetect platform; build specialisation configurations for wayland and x11_egpu; set default boot menu selection to wayland:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}system${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}spec${RESET}${RED}=${RESET}\
wayland${RED},${RESET}x11_egpu ${BLUE}BOOT_SPEC${RESET}${RED}=${RESET}1\n"

write_line "  ${GREEN}- Rebuild and switch the current system's configuration and current user's home-manager configuration; autodetect all settings:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}all${RESET}\n"

write_line "  ${GREEN}- Evaluate the current system's configuration and current user's home-manager config; autodetect all settings:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}all${RESET} ${BLUE}DRY_RUN${RESET}${RED}=${RESET}1\n"

write_line "  ${GREEN}- Run 'nix flake check' for all configurations (current system and user must have a valid configuration):${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}test${RESET}\n"
