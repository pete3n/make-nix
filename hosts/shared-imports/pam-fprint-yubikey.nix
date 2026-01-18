# Fingerprint or yubikey auth for laptops
{ config, pkgs, lib, makeNixAttrs, ... }:

let
  homeDir = config.users.users.${makeNixAttrs.user}.home or "/home/${makeNixAttrs.user}";
  u2f_keyfile = "${homeDir}/.config/Yubico/u2f_keys";
  u2f = config.security.pam.u2f.settings;
in
{
  services.fprintd.enable = true;

  security.pam.services.sudo = {
    # prevent generated stacks from being appended
    u2fAuth    = lib.mkForce false;
    fprintAuth = lib.mkForce false;

    # Require (U2F OR fingerprint); try U2F first
    text = lib.mkForce ''
      # Factor: YubiKey U2F (preferred)
      auth sufficient ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
        cue \
        origin=${u2f.origin} \
        appid=${u2f.appid} \
        authfile=${u2f_keyfile} \
        openasuser \
        expand

      # Factor: fingerprint (fallback)
      auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so max-tries=1 timeout=3

      # If neither works, deny
      auth required ${pkgs.linux-pam}/lib/security/pam_deny.so

      account required ${pkgs.linux-pam}/lib/security/pam_unix.so
      session required ${pkgs.linux-pam}/lib/security/pam_unix.so
    '';
  };
}
