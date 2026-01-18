# Customize pam for SSH server
{ lib, pkgs, ... }:
{
  security.pam.services = {
    sudo.u2fAuth = lib.mkForce false;
    pam.services.sudo.text = lib.mkForce ''
      # If this is an SSH session (pts/*), skip U2F.
      auth [success=1 default=ignore] ${pkgs.linux-pam}/lib/security/pam_succeed_if.so tty =~ ^/dev/pts/

      # Local console sudo requires YubiKey
      auth required ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
        cue origin=pam://p22 appid=pam://p22 \
        authfile=%h/.config/Yubico/u2f_keys openasuser=1

      # SSH sudo falls back to password (if allowed)
      auth required ${pkgs.linux-pam}/lib/security/pam_unix.so try_first_pass

      account required ${pkgs.linux-pam}/lib/security/pam_unix.so
      session required ${pkgs.linux-pam}/lib/security/pam_unix.so
    '';
  };
}
