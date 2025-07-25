#!/usr/bin/env sh
set -eu

if [ ${NO_ANSI+x} ]; then
	# shellcheck disable=SC1091
	. "$(dirname "$0")/no_ansi.env"
	help_file="$(dirname "$0")/no_ansi_help.txt"
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
write_line "${RED}make${RESET} ${BOLD}<help|install|home|system|all|test>${RESET} [${CYAN}host${RESET}${RED}=${RESET}<host>]\
[${CYAN}user${RESET}${RED}=${RESET}<user>] [${CYAN}system${RESET}${RED}=${RESET}<system>] [${CYAN}spec${RESET}${RED}=${RESET}\
<spc1>${RED},${RESET}<spc2>${RED},${RESET}<spc3>${RED},${RESET}...] [${BLUE}option flags${RESET}]"

write_line ""
write_line "Make targets:"
write_line "  ${BOLD}help${RESET}    - You are here."
write_line "  ${BOLD}install${RESET} - Install Nix or Nix-Darwin."
write_line "  ${BOLD}home${RESET}    - Build and activate a Home-manager configuration."
write_line "  ${BOLD}system${RESET}  - Build and activate a NixOS or Nix-Darwin system configuration."
write_line "  ${BOLD}all${RESET}     - Execute both the system and home targets in that order."
write_line "  ${BOLD}test${RESET}    - Check all flake configurations."

write_line ""
write_line "Required arguments:"
write_line "  ${CYAN}host${RESET}    - System configuration host (current hostname will be passed by default)."
write_line "  ${CYAN}user${RESET}    - User configuration (current user will be passed by default)."
write_line "  ${CYAN}system${RESET}  - System platform to target for builds: x86_64-linux, aarch64-linux, x86_64-darwin, or aarch64-darwin "
write_line "(current platform will be passed by default.)"

write_line ""
write_line "Optional arguments:"
write_line "  ${CYAN}spec${RESET}    - Comma separated list of system specialisation configurations (no spaces)."

write_line ""
write_line "Install option flags (assigning any value will enable them):"
write_line "  ${BLUE}SINGLE_USER${RESET}${RED}=${RESET}true  - Install Nix for single-user mode."
write_line "  ${BLUE}DETERMINATE${RESET}${RED}=${RESET}true  - Install Nix using the Determinate Systems installer."
write_line "  ${BLUE}NIX_DARWIN${RESET}${RED}=${RESET}true   - Install Nix-Darwin for MacOS."
write_line "  ${BLUE}NIXGL${RESET}${RED}=${RESET}true        - Install NixGL; OpenGL and Vulkan wrapper for non-NixOS systems."

write_line ""
write_line "Home|system|all option flags:"
write_line "  ${BLUE}DRY_RUN${RESET}${RED}=${RESET}true      - Evaluate the new configuration but don't activate it."
write_line "  ${BLUE}BOOT_SPEC${RESET}${RED}=${RESET}true    - Set the default boot menu option to the ${BOLD}first${RESET} listed specialisation."

write_line ""
write_line "Usage examples:"
write_line "  ${GREEN}- Switch the home-manager configuration for current user; autodetect system type:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}home${RESET}"

write_line "  ${GREEN}- Switch the home-manager configuration for user joe; autodetect system type:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${CYAN}user${RESET}${RED}=${RESET}joe"

write_line "  ${GREEN}- Switch the home-manager configuration for user sam; target an aarch64-darwin platform:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${CYAN}user${RESET}${RED}=${RESET}sam ${CYAN}system${RESET}${RED}=${RESET}aarch64-darwin"

write_line "  ${GREEN}- Rebuild and switch the current system's configuration; autodetect hostname and system platform:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}system${RESET}"

write_line "  ${GREEN}- Rebuild and switch the system configuration for host workstation1; target an aarch64-linux platform:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}system${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}system${RESET}${RED}=${RESET}aarch64-linux"

write_line "  ${GREEN}- Rebuild and switch the system configuration for host workstation1; autodetect platform; build specialisation configurations for wayland and x11_egpu; set default boot menu selection to wayland:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}system${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}spec${RESET}${RED}=${RESET}wayland${RED},${RESET}x11_egpu ${BLUE}BOOT_SPEC${RESET}${RED}=1${RESET}"

write_line "  ${GREEN}- Rebuild and switch the current system's configuration and current user's home-manager configuration; autodetect all settings:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}all${RESET}"

write_line "  ${GREEN}- Evaluate the current system's configuration and current user's home-manager config; autodetect all settings:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}all${RESET} ${BLUE}DRY_RUN${RESET}${RED}=1${RESET}"

write_line "  ${GREEN}- Rebuild and switch system config and home-manager config for user joe on workstation1 (x86_64-linux):${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}all${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}system${RESET}${RED}=${RESET}x86_64-linux ${CYAN}user${RESET}${RED}=${RESET}joe"

write_line "  ${GREEN}- Run 'nix flake check' for all configurations:${RESET}"
write_line "    ${RED}make${RESET} ${BOLD}test${RESET}"
