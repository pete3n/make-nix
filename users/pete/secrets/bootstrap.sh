#!/usr/bin/env bash
# Bootstrap agenix secrets for a new host
# Prerequisites: Yubikey plugged in, agenix and age-plugin-yubikey in PATH,
# nixos-rebuild already run at least once (sshd started, host keys generated)

set -u

SECRETS_DIR="${1:-./users/pete/secrets}"
IDENTITY="/etc/static/age/pete/age-plugin-yubikeys"
HOST_KEY="/etc/ssh/ssh_host_ed25519_key.pub"

# 1. Verify prerequisites
if [ ! -f "${HOST_KEY}" ]; then
  printf "Host key not found at %s\n" "${HOST_KEY}" >&2
  printf "Ensure services.openssh.enable = true and sshd has started at least once\n" >&2
  exit 1
fi

if [ ! -f "${IDENTITY}" ]; then
  printf "Yubikey identity not found at %s\n" "${IDENTITY}" >&2
  exit 1
fi

# 2. Display host public key — operator must manually verify it matches secrets.nix
printf "Host public key:\n"
cat "${HOST_KEY}"
printf "\nVerify this key is present in secrets.nix before continuing.\n"
printf "Press enter to continue or Ctrl-C to abort...\n"
read -r _

# 3. Re-encrypt all secrets to include the host key as a recipient
# Requires Yubikey touch
cd "${SECRETS_DIR}" || exit 1
agenix -r -i "${IDENTITY}"

printf "Done. Rebuild and reboot to verify boot-time decryption.\n"
