#!/usr/bin/env sh
set -eu
# shellcheck disable=SC1091
. "$(dirname "$0")/ansi.env"

ROWS=$(tput lines 2>/dev/null)
: "${ROWS:=24}"
LINES_SHOWN=0

print_line() {
  printf "%b\n" "$1"
  LINES_SHOWN=$((LINES_SHOWN + 1))
  if [ "$LINES_SHOWN" -ge $((ROWS - 2)) ]; then
    printf "%b-- More -- [Press enter]%b" "$BOLD" "$RESET"
		# shellcheck disable=SC2034
    read -r dummy
    printf "\n"
    LINES_SHOWN=0
  fi
}

print_line "Usage:"
print_line "${RED}make${RESET} ${BOLD}<help|install|home|system|all|test>${RESET} [${CYAN}host${RESET}${RED}=${RESET}<host>]\
[${CYAN}user${RESET}${RED}=${RESET}<user>] [${CYAN}system${RESET}${RED}=${RESET}<system>] [${CYAN}spec${RESET}${RED}=${RESET}\
<spc1>${RED},${RESET}<spc2>${RED},${RESET}<spc3>${RED},${RESET}...] [${BLUE}option flags${RESET}]"

print_line ""
print_line "Make targets:"
print_line "  ${BOLD}help${RESET}    - You are here."
print_line "  ${BOLD}install${RESET} - Install Nix or Nix-Darwin."
print_line "  ${BOLD}home${RESET}    - Build and activate a Home-manager configuration."
print_line "  ${BOLD}system${RESET}  - Build and activate a NixOS or Nix-Darwin system configuration."
print_line "  ${BOLD}all${RESET}     - Execute both the system and home targets in that order."
print_line "  ${BOLD}test${RESET}    - Check all flake configurations."

print_line ""
print_line "Required arguments:"
print_line "  ${CYAN}host${RESET}    - System configuration host (current hostname will be passed by default)."
print_line "  ${CYAN}user${RESET}    - User configuration (current user will be passed by default)."
print_line "  ${CYAN}system${RESET}  - System platform to target for builds: x86_64-linux, aarch64-linux, x86_64-darwin, or aarch64-darwin "
print_line "(current platform will be passed by default.)"

print_line ""
print_line "Optional arguments:"
print_line "  ${CYAN}spec${RESET}    - Comma separated list of system specialisation configurations (no spaces)."

print_line ""
print_line "Install option flags (assigning any value will enable them):"
print_line "  ${BLUE}SINGLE_USER${RESET}${RED}=${RESET}true  - Install Nix for single-user mode."
print_line "  ${BLUE}DETERMINATE${RESET}${RED}=${RESET}true  - Install Nix using the Determinate Systems installer."
print_line "  ${BLUE}NIX_DARWIN${RESET}${RED}=${RESET}true   - Install Nix-Darwin for MacOS."
print_line "  ${BLUE}NIXGL${RESET}${RED}=${RESET}true        - Install NixGL; OpenGL and Vulkan wrapper for non-NixOS systems."

print_line ""
print_line "Home|system|all option flags:"
print_line "  ${BLUE}DRY_RUN${RESET}${RED}=${RESET}true      - Evaluate the new configuration but don't activate it."
print_line "  ${BLUE}BOOT_SPEC${RESET}${RED}=${RESET}true    - Set the default boot menu option to the ${BOLD}first${RESET} listed specialisation."

print_line ""
print_line "Usage examples:"
print_line "  ${GREEN}- Switch the home-manager configuration for current user; autodetect system type:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}home${RESET}"

print_line "  ${GREEN}- Switch the home-manager configuration for user joe; autodetect system type:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${CYAN}user${RESET}${RED}=${RESET}joe"

print_line "  ${GREEN}- Switch the home-manager configuration for user sam; target an aarch64-darwin platform:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}home${RESET} ${CYAN}user${RESET}${RED}=${RESET}sam ${CYAN}system${RESET}${RED}=${RESET}aarch64-darwin"

print_line "  ${GREEN}- Rebuild and switch the current system's configuration; autodetect hostname and system platform:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}system${RESET}"

print_line "  ${GREEN}- Rebuild and switch the system configuration for host workstation1; target an aarch64-linux platform:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}system${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}system${RESET}${RED}=${RESET}aarch64-linux"

print_line "  ${GREEN}- Rebuild and switch the system configuration for host workstation1; autodetect platform; build specialisation configurations for wayland and x11_egpu; set default boot menu selection to wayland:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}system${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}spec${RESET}${RED}=${RESET}wayland${RED},${RESET}x11_egpu ${BLUE}BOOT_SPEC${RESET}${RED}=1${RESET}"

print_line "  ${GREEN}- Rebuild and switch the current system's configuration and current user's home-manager configuration; autodetect all settings:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}all${RESET}"

print_line "  ${GREEN}- Evaluate the current system's configuration and current user's home-manager config; autodetect all settings:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}all${RESET} ${BLUE}DRY_RUN${RESET}${RED}=1${RESET}"

print_line "  ${GREEN}- Rebuild and switch system config and home-manager config for user joe on workstation1 (x86_64-linux):${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}all${RESET} ${CYAN}host${RESET}${RED}=${RESET}workstation1 ${CYAN}system${RESET}${RED}=${RESET}x86_64-linux ${CYAN}user${RESET}${RED}=${RESET}joe"

print_line "  ${GREEN}- Run 'nix flake check' for all configurations:${RESET}"
print_line "    ${RED}make${RESET} ${BOLD}test${RESET}"
