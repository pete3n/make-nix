# Customize pam for SSH server
{
  config,
  pkgs,
  lib,
  makeNixAttrs,
  ...
}:

let
  homeDir = config.users.users.${makeNixAttrs.user}.home or "/home/${makeNixAttrs.user}";
  u2f_keyfile = "${homeDir}/.config/Yubico/u2f_keys";
  u2f = config.security.pam.u2f.settings;
in
{
  security.pam.services = {
		# Don't require u2f for local login
    login.u2fAuth = lib.mkForce false;
    system-login.u2fAuth = lib.mkForce false;
    sudo = {
      u2fAuth = lib.mkForce false;
      fprintAuth = lib.mkForce false;

      text = lib.mkForce ''
        # If this is an SSH session (pts/*), skip the next line (U2F)
        auth [success=1 default=ignore] ${pkgs.linux-pam}/lib/security/pam_succeed_if.so tty =~ ^/dev/pts/

        # Local console sudo requires YubiKey
        auth required ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
          cue \
          origin=${u2f.origin} \
          appid=${u2f.appid} \
          authfile=${u2f_keyfile} \
          openasuser \
          expand

        # SSH sudo fallback 
        auth required ${pkgs.linux-pam}/lib/security/pam_unix.so try_first_pass

        account required ${pkgs.linux-pam}/lib/security/pam_unix.so
        session required ${pkgs.linux-pam}/lib/security/pam_unix.so
      '';
    };

  };
}
