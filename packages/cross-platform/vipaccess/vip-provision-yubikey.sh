#!/usr/bin/env bash
# vip-provision-yubikey
#
# Provisions a Symantec VIP Access credential inside a bubblewrap sandbox,
# then immediately imports the TOTP secret to a Yubikey via ykman.
#
# Nothing is written to your home directory or filesystem.
# The secret exists in a tmpfs inside the sandbox, is read once for ykman
# import, and then the sandbox tears down and takes the tmpfs with it.
#
# Prerequisites (must be in PATH or provided via nix shell):
#   - vipaccess  (python-vipaccess)
#   - bwrap      (bubblewrap)
#   - ykman      (yubikey-manager)
#
# Usage:
#   vip-provision-yubikey [options]
#
# Options:
#   -t MODEL   Token model: SYMC (default) or SYDC
#              Some institutions require one or the other.
#   -n NAME    OATH account name on the Yubikey (default: VIP)
#   --no-touch Disable touch requirement (not recommended)
#   -h         Show this help
#
# What this contacts over the network (provisioning step only):
#   1. https://services.vip.symantec.com/prov  — request new token
#   2. https://vip.symantec.com/otpCheck       — verify token works
#
# After this script completes, no further network contact occurs ever.
# The Yubikey computes OTP codes entirely on-device from the stored secret.

set -eu
TOKEN_MODEL="SYMC"
ACCOUNT_NAME="VIP"
REQUIRE_TOUCH="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--token-model) TOKEN_MODEL="$2"; shift 2 ;;
    -n|--name)        ACCOUNT_NAME="$2"; shift 2 ;;
    --no-touch)       REQUIRE_TOUCH="false"; shift ;;
    -h|--help)
      grep '^#' "$0" | grep -v '^#!' | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

for cmd in bwrap vipaccess ykman; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' not found in PATH." >&2
    echo "Run this script via: nix shell nixpkgs#bubblewrap nixpkgs#python3Packages.python-vipaccess nixpkgs#yubikey-manager" >&2
    exit 1
  fi
done

echo "Checking for Yubikey..."
if ! ykman info &>/dev/null; then
  echo "ERROR: No Yubikey detected. Insert your Yubikey and try again." >&2
  exit 1
fi

echo "Yubikey found."
echo ""

# Sandbox setup — tmpfs only
# We use a tmpfs inside the sandbox as the output location.
# bwrap --tmpfs mounts are not backed by any real directory on the host —
# they exist only in the sandbox's memory and disappear when bwrap exits.
# We communicate the result out via a pipe on stdout.

echo "=== Sandboxed VIP Access Provisioning ==="
echo ""
echo "Token model : $TOKEN_MODEL"
echo "Account name: $ACCOUNT_NAME (on Yubikey OATH)"
echo "Touch required: $REQUIRE_TOUCH"
echo ""
echo "Network contacts (this step only):"
echo "  services.vip.symantec.com/prov  — request token"
echo "  vip.symantec.com/otpCheck       — verify token"
echo ""

# Run vipaccess inside the sandbox, printing the credential to stdout (-p flag).
# stdout is NOT sandboxed — it flows directly to this script's variable capture.
# The sandbox has no writable paths on the host filesystem at all.
#
# Sandbox constraints:
#   /nix     ro — Python runtime
#   /etc/ssl ro — TLS CA certs for HTTPS validation
#   /etc/resolv.conf ro — DNS
#   /tmp     tmpfs — Python may need this; isolated from host /tmp
#   /home    tmpfs — home is invisible; vipaccess won't try to write ~/.vipaccess
#            because we use -p (print) mode, not -o (file) mode
#   No other host paths are mounted.

PROVISION_OUTPUT=$(
  bwrap \
    --ro-bind /nix /nix \
    --ro-bind-try /etc/ssl /etc/ssl \
    --ro-bind-try /etc/static/ssl /etc/static/ssl \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --tmpfs /tmp \
    --tmpfs /home \
    --tmpfs /root \
    --proc /proc \
    --dev /dev \
    --unshare-pid \
    --unshare-ipc \
    --unshare-uts \
    --new-session \
    --setenv HOME /home \
    --setenv TMPDIR /tmp \
    -- \
    vipaccess provision --print --token-model "$TOKEN_MODEL"
)

# vipaccess provision -p prints:
#   Credential created successfully:
#       otpauth://totp/VIP%20Access:SYMCXXXXXXXX?secret=BASE32SECRET&...
#   This credential expires on this date: YYYY-MM-DDTHH:MM:SS.mmmZ
#   You will need the ID to register this credential: SYMCXXXXXXXX
#   ...

OTPAUTH_URI=$(echo "$PROVISION_OUTPUT" | grep -o 'otpauth://[^ ]*')
CREDENTIAL_ID=$(echo "$PROVISION_OUTPUT" | grep 'You will need the ID' | grep -o 'SY[A-Z0-9]*\|VS[A-Z0-9]*' | head -1)
EXPIRY=$(echo "$PROVISION_OUTPUT" | grep 'expires on this date' | grep -o '[0-9T:Z.-]*$')
SECRET=$(echo "$OTPAUTH_URI" | grep -o 'secret=[^&]*' | cut -d= -f2)

if [[ -z "$SECRET" || -z "$CREDENTIAL_ID" ]]; then
  echo "" >&2
  echo "ERROR: Failed to parse provisioning output." >&2
  echo "Raw output:" >&2
  echo "$PROVISION_OUTPUT" >&2
  exit 1
fi

echo ""
echo "Provisioning successful."
echo "  Credential ID : $CREDENTIAL_ID"
echo "  Expires       : $EXPIRY"

# ykman oath accounts add parameters:
#   -o TOTP   — time-based OTP (matches VIP Access)
#   -a SHA1   — HMAC algorithm (matches VIP Access provisioned token)
#   -d 6      — 6-digit codes
#   -P 30     — 30-second period
#   -t        — require physical touch to generate a code (recommended)
#               prevents malware from silently generating codes
#
# The same secret is written to each key in sequence. ykman is told which
# key to target by serial number (-d), so only the intended key is written
# at each step even if both are plugged in simultaneously.
#
# WARNING: ykman does not allow reading secrets back off a Yubikey.
# The only opportunity to program a backup key with the same secret is
# during this session, while the secret is still in memory.

TOUCH_FLAG=""
if [[ "$REQUIRE_TOUCH" == "true" ]]; then
  TOUCH_FLAG="-t"
fi

import_to_key() {
  local serial="$1"
  local label="$2"

  echo "Importing to Yubikey (serial: $serial)..."
  # shellcheck disable=SC2086
  ykman --device "$serial" oath accounts add \
    -o TOTP \
    -a SHA1 \
    -d 6 \
    -P 30 \
    $TOUCH_FLAG \
    "$ACCOUNT_NAME" \
    "$SECRET"
  echo "  ✓ $label (serial: $serial) — import successful"
}

# Collect serials of all currently connected keys
mapfile -t SERIALS < <(ykman list --serials 2>/dev/null)

if [[ ${#SERIALS[@]} -eq 0 ]]; then
  echo "ERROR: No Yubikeys detected." >&2
  exit 1
fi

KEY_COUNT=1
for SERIAL in "${SERIALS[@]}"; do
  echo ""
  echo "--- Key $KEY_COUNT (serial: $SERIAL) ---"
  import_to_key "$SERIAL" "Key $KEY_COUNT"
  (( KEY_COUNT++ )) || true
done

while true; do
  echo ""
  read -r -p "Import to another Yubikey? (swap key now, then press y, or press n to finish): " ANOTHER
  case "$ANOTHER" in
    [Yy]*)
      # Re-scan for connected keys, find any new serial
      mapfile -t CURRENT_SERIALS < <(ykman list --serials 2>/dev/null)
      NEW_SERIALS=()
      for S in "${CURRENT_SERIALS[@]}"; do
        already=false
        for DONE in "${SERIALS[@]}"; do
          [[ "$S" == "$DONE" ]] && already=true
        done
        $already || NEW_SERIALS+=("$S")
      done

      if [[ ${#NEW_SERIALS[@]} -eq 0 ]]; then
        echo "No new Yubikey detected. Make sure the new key is connected and try again."
      else
        for SERIAL in "${NEW_SERIALS[@]}"; do
          echo ""
          echo "--- Key $KEY_COUNT (serial: $SERIAL) ---"
          import_to_key "$SERIAL" "Key $KEY_COUNT"
          SERIALS+=("$SERIAL")
          (( KEY_COUNT++ )) || true
        done
      fi
      ;;
    [Nn]*) break ;;
    *) echo "Please answer y or n." ;;
  esac
done

echo ""
echo "=== Done ==="
echo ""
echo "Secret imported to ${#SERIALS[@]} Yubikey(s): ${SERIALS[*]}"
echo "The secret has NOT been written to disk anywhere."
echo ""
echo "=== Enrollment workflow ==="
echo ""
echo "1. Generate a test code to confirm a key is working (use either key):"
echo "     ykman oath accounts code $ACCOUNT_NAME"
echo "   (touch the key when prompted)"
echo ""
echo "2. Go to your financial institution's security settings and"
echo "   add a VIP Access / security token. When prompted, provide:"
echo ""
echo "     Credential ID : $CREDENTIAL_ID"
echo "     6-digit code  : (run the command above)"
echo ""
echo "3. The institution may ask for a second code to confirm."
echo "   Wait for the next 30-second window and run the command again."
echo ""
echo "Both keys will produce identical codes — either can be used for login."
echo ""
echo "If enrollment is rejected, the institution may require the other"
echo "token model. Delete from all keys and re-provision:"
for S in "${SERIALS[@]}"; do
  echo "  ykman --device $S oath accounts delete $ACCOUNT_NAME"
done
echo "  vip-provision-yubikey -t SYDC   # if you used SYMC, or vice versa"
