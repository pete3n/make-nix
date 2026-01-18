# Fingerprint or yubikey auth for laptops
{ lib, pkgs, ... }:
{
  # Fingerprint support
  services.fprintd.enable = true;

  # Allow customizing sudo
  security.pam.services.sudo.u2fAuth = lib.mkForce false;

  security.pam.services.sudo.text = lib.mkForce ''
    # Try YubiKey first (fast fail if absent), then fingerprint.

    auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
      cue origin=pam://p22 appid=pam://p22 \
      authfile=%h/.config/Yubico/u2f_keys openasuser=1

    auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=1 timeout=3

    # If neither worked, deny sudo.
    auth required ${pkgs.linux-pam}/lib/security/pam_deny.so

    account required ${pkgs.linux-pam}/lib/security/pam_unix.so
    session required ${pkgs.linux-pam}/lib/security/pam_unix.so
  '';
}
